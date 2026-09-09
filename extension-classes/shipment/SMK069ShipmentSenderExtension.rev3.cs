using System;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using Mongoose.IDO;
using Mongoose.IDO.Protocol;

namespace SMK069Shipment
{
    /*  =========================================================================
        REVISION 3 - 8 September 2026
        -------------------------------------------------------------------------
        >>> DIFF THIS AGAINST THE TENANT SOURCE BEFORE REPLACING IT. <<<
        This file is derived from the revision read on 4 Sep. If the class was
        edited in the tenant after that - for example while moving DN_No to a
        string - those edits are NOT in here. Compare first; do not paste over
        work you cannot see.

        1. DN_No is a string everywhere.
           Since 7 Sep SMK069_ShipmentAPI_mst emits a prefixed DN (P96325) and
           the SQL chain moved to NVARCHAR. A long parameter cannot carry that,
           which is what produced

               IDOValueType.GetValue: failed to parse normalized string
               [P96325], Type = Int64

           The IDO method metadata must be changed to String in the same pass,
           for SMK069SendOneShipment, SMK069SendOneShipmentKacs and the Prepare
           stored-procedure method. Positions do not move; only the type.

        2. The shipment path constant now points at infor_dn.
           kacs_dn is the KACS direction; Infor to POS is infor_dn. See docs/28.
           The base path is still disputed - /inventory/v1/ was the URL sent,
           while "just swap kacs_dn for infor_dn" implies /inventory-phi/v1/.
           The batch sender does not use this constant at all: it reads
           endpoint_url from ue_SMK069_shipment_config_mst, so the disputed value
           can be corrected without a rebuild.

        3. New: SMK069SendPendingShipments, the hourly batch sender.
           Policy lives in SQL - which shipments are due, the backoff, the
           attempt budget. This method only logs in once, loops, and performs
           the HTTP call. See docs/29.

        NOT CHANGED
        -----------
        No TLS pinning was added. An earlier attempt from this class reached the
        real UAT host and came back with HTTP 401, which proves the handshake
        already succeeds; ServicePointManager.SecurityProtocol is process-wide
        and should not be touched on a hunch.
        ========================================================================= */

    /// <summary>
    /// Server-side transport for SMK069 Shipment outbound.
    ///
    /// Production concept:
    /// DN_No -> Prepare/build payload -> POS login -> Shipment POST -> Complete.
    ///
    /// The endpoint URL and Authorization header are transport concerns and are
    /// never inserted into the Shipment business JSON payload.
    /// </summary>
    [IDOExtensionClass("ue_SMK069ShipmentTransport")]
    public class SMK069ShipmentTransportExtension : IDOExtensionClass
    {
        private const int DefaultTimeoutSeconds = 60;
        private const int MaximumTimeoutSeconds = 300;
        private const int MaximumReturnedBodyChars = 1048576;

        private const string PosUatBaseUrl = "https://api-uat.pizzahut.co.id";
        private const string PosProdBaseUrl = "https://api-prod.pizzahut.co.id";
        private const string PosLoginPath = "/service-auth/login-once";

        /*  Infor -> POS. NOT kacs_dn: that is the KACS direction.
            Base path still to be confirmed with the POS team - docs/28 section 6.
            Only SMK069SendOneShipmentKacs depends on this; the batch sender
            takes its endpoint from configuration.                              */
        private const string PosShipmentPath = "/inventory/v1/infor_dn";

        /// <summary>
        /// Hourly batch sender. Reads its policy from SQL, logs in once, then
        /// sends every due shipment independently. One failure never stops the
        /// run, and every attempt is recorded so the backoff advances.
        ///
        /// Keep this IDO method NON-TRANSACTIONAL: it performs external HTTP.
        ///
        /// Username and Password come from the TaskMan task definition. Mongoose
        /// echoes input parameters back in the IDO response, so do NOT invoke
        /// this interactively with production credentials.
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int SMK069SendPendingShipments(
            string Username,
            string Password,
            int MaxShipments,
            ref int Candidates,
            ref int Succeeded,
            ref int Failed,
            ref int Exhausted,
            ref string FailedList,
            ref string Infobar)
        {
            Candidates = 0;
            Succeeded = 0;
            Failed = 0;
            Exhausted = 0;
            FailedList = null;
            Infobar = null;

            if (string.IsNullOrWhiteSpace(Username) ||
                string.IsNullOrWhiteSpace(Password))
            {
                Infobar = "Username dan Password POS wajib diisi pada definisi task.";
                return 16;
            }

            // ---- configuration ------------------------------------------------
            int isEnabled;
            string loginUrl;
            string endpointUrl;
            string successMode;
            int timeoutSeconds;
            string configInfobar;

            try
            {
                ReadShipmentConfig(
                    out isEnabled,
                    out loginUrl,
                    out endpointUrl,
                    out successMode,
                    out timeoutSeconds,
                    out configInfobar);
            }
            catch (Exception ex)
            {
                Infobar = "Konfigurasi Shipment tidak terbaca: " + ex.Message;
                return 16;
            }

            if (isEnabled != 1)
            {
                // A deliberate off switch is not a failure.
                Infobar = string.IsNullOrWhiteSpace(configInfobar)
                    ? "Scheduler Shipment dinonaktifkan (is_enabled = 0)."
                    : configInfobar;
                return 0;
            }

            if (string.IsNullOrWhiteSpace(endpointUrl) ||
                string.IsNullOrWhiteSpace(loginUrl))
            {
                Infobar = "endpoint_url atau login_url belum diisi pada konfigurasi.";
                return 16;
            }

            timeoutSeconds = NormalizeTimeout(timeoutSeconds);

            // ---- which shipments are due --------------------------------------
            string pendingList;
            int dueLater;
            string pendingInfobar;

            try
            {
                ReadPendingShipments(
                    MaxShipments,
                    out pendingList,
                    out Candidates,
                    out dueLater,
                    out Exhausted,
                    out pendingInfobar);
            }
            catch (Exception ex)
            {
                Infobar = "Daftar Shipment pending tidak terbaca: " + ex.Message;
                return 16;
            }

            if (string.IsNullOrWhiteSpace(pendingList))
            {
                Infobar = string.IsNullOrWhiteSpace(pendingInfobar)
                    ? "Tidak ada Shipment yang perlu dikirim."
                    : pendingInfobar;
                return 0;
            }

            // ---- one login for the whole run ----------------------------------
            string accessToken;
            string loginResponse;
            string loginError;
            int loginHttpCode;

            bool loginOk = TryPosLogin(
                loginUrl,
                Username,
                Password,
                timeoutSeconds,
                out loginHttpCode,
                out loginResponse,
                out accessToken,
                out loginError);

            if (!loginOk)
            {
                /*  Nothing was sent, so no attempt is recorded and no backoff
                    advances. A credential problem must not consume the attempt
                    budget of every pending shipment.                           */
                Infobar =
                    "Login POS gagal; tidak ada Shipment yang dikirim. " +
                    (string.IsNullOrWhiteSpace(loginError)
                        ? string.Empty
                        : loginError);
                return 16;
            }

            string authValue = "Bearer " + accessToken;
            accessToken = null;

            // ---- send each shipment independently ------------------------------
            StringBuilder failedDetail = new StringBuilder();
            string[] shipments = pendingList.Split(',');

            foreach (string rawDn in shipments)
            {
                string dn = (rawDn ?? string.Empty).Trim();
                if (dn.Length == 0)
                {
                    continue;
                }

                string logRowPointer = null;
                string payloadJson = null;
                string responseJson = null;
                string errorMessage = null;
                string oneInfobar = null;
                int httpCode = 0;
                int transportSuccess = 0;
                int businessSuccess = 0;
                int oneSuccess = 0;

                try
                {
                    SMK069SendOneShipment(
                        dn,
                        endpointUrl,
                        "Authorization",
                        authValue,
                        successMode,
                        string.Empty,
                        timeoutSeconds,
                        ref logRowPointer,
                        ref payloadJson,
                        ref httpCode,
                        ref responseJson,
                        ref transportSuccess,
                        ref businessSuccess,
                        ref errorMessage,
                        ref oneSuccess,
                        ref oneInfobar);
                }
                catch (Exception ex)
                {
                    oneSuccess = 0;
                    errorMessage = AppendMessage(errorMessage, "Exception: " + ex.Message);
                }

                // Record the attempt whatever happened, so the backoff advances.
                int attemptCount = 0;
                int thisExhausted = 0;
                string recordInfobar = null;

                try
                {
                    RecordShipmentAttempt(
                        dn,
                        oneSuccess == 1,
                        httpCode,
                        errorMessage,
                        out attemptCount,
                        out thisExhausted,
                        out recordInfobar);
                }
                catch (Exception ex)
                {
                    recordInfobar = "Gagal mencatat percobaan: " + ex.Message;
                }

                if (oneSuccess == 1)
                {
                    Succeeded++;
                }
                else
                {
                    Failed++;

                    if (thisExhausted == 1)
                    {
                        Exhausted++;
                    }

                    if (failedDetail.Length < 1500)
                    {
                        if (failedDetail.Length > 0)
                        {
                            failedDetail.Append(" | ");
                        }

                        failedDetail
                            .Append(dn)
                            .Append(": ")
                            .Append(recordInfobar ?? errorMessage ?? "gagal");
                    }
                }
            }

            FailedList = failedDetail.Length == 0 ? null : failedDetail.ToString();

            Infobar = string.Format(
                CultureInfo.InvariantCulture,
                "SMK069 Shipment batch. Kandidat={0}; terkirim={1}; gagal={2}; " +
                "berhenti dicoba={3}; menunggu backoff={4}.{5}",
                Candidates,
                Succeeded,
                Failed,
                Exhausted,
                dueLater,
                FailedList == null ? string.Empty : " Detail: " + FailedList);

            return 0;
        }

        /// <summary>
        /// Simple POS orchestration for one shipment, resolving the URL from the
        /// environment name instead of configuration. Kept for manual UAT.
        ///
        /// The access token is deliberately never returned or logged.
        ///
        /// Keep this IDO method NON-TRANSACTIONAL because it performs external HTTP.
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int SMK069SendOneShipmentKacs(
            string DN_No,
            string ApiEnvironment,
            string Username,
            string Password,
            int TimeoutSeconds,
            ref string LogRowPointer,
            ref string PayloadJson,
            ref int LoginHttpCode,
            ref int HttpCode,
            ref string ResponseJson,
            ref int TransportSuccess,
            ref int BusinessSuccess,
            ref string ErrorMessage,
            ref int Success,
            ref string Infobar)
        {
            LogRowPointer = null;
            PayloadJson = null;
            LoginHttpCode = 0;
            HttpCode = 0;
            ResponseJson = null;
            TransportSuccess = 0;
            BusinessSuccess = 0;
            ErrorMessage = null;
            Success = 0;
            Infobar = null;

            if (string.IsNullOrWhiteSpace(DN_No))
            {
                ErrorMessage = "DN_No wajib diisi.";
                Infobar = ErrorMessage;
                return 16;
            }

            DN_No = DN_No.Trim();

            string loginUrl;
            string shipmentUrl;
            if (!ResolvePosUrls(ApiEnvironment, out loginUrl, out shipmentUrl, ref ErrorMessage))
            {
                Infobar = ErrorMessage;
                return 16;
            }

            if (string.IsNullOrWhiteSpace(Username) ||
                string.IsNullOrWhiteSpace(Password))
            {
                ErrorMessage = "POS Username dan Password wajib diisi saat runtime.";
                Infobar = ErrorMessage;
                return 16;
            }

            int timeoutSeconds = NormalizeTimeout(TimeoutSeconds);

            Guid logRowPointer;
            int prepareSuccess;
            string prepareInfobar;

            try
            {
                ExecutePrepareShipmentSend(
                    DN_No,
                    shipmentUrl,
                    out logRowPointer,
                    out PayloadJson,
                    out prepareSuccess,
                    out prepareInfobar);
            }
            catch (Exception ex)
            {
                ErrorMessage = "Prepare Shipment exception: " + ex.Message;
                Infobar = ErrorMessage;
                return 16;
            }

            if (prepareSuccess != 1 || logRowPointer == Guid.Empty)
            {
                ErrorMessage = string.IsNullOrWhiteSpace(prepareInfobar)
                    ? "Prepare Shipment gagal."
                    : prepareInfobar;
                Infobar = ErrorMessage;
                return 16;
            }

            LogRowPointer = logRowPointer.ToString();

            string accessToken;
            string loginResponse;
            string loginError;

            bool loginOk = TryPosLogin(
                loginUrl,
                Username,
                Password,
                timeoutSeconds,
                out LoginHttpCode,
                out loginResponse,
                out accessToken,
                out loginError);

            if (!loginOk)
            {
                ErrorMessage = string.IsNullOrWhiteSpace(loginError)
                    ? "POS login gagal."
                    : loginError;

                ResponseJson = BuildStageResponse(
                    "LOGIN",
                    LoginHttpCode,
                    SanitizeLoginResponse(loginResponse),
                    ErrorMessage);

                int completeSuccess;
                string completeInfobar;

                try
                {
                    ExecuteCompleteShipmentSend(
                        logRowPointer,
                        LoginHttpCode,
                        ResponseJson,
                        0,
                        out completeSuccess,
                        out completeInfobar);
                }
                catch (Exception ex)
                {
                    ErrorMessage = AppendMessage(
                        ErrorMessage,
                        "Complete Shipment exception setelah login gagal: " + ex.Message);
                    Infobar = ErrorMessage;
                    return 16;
                }

                Infobar =
                    "POS login gagal; Shipment DN " + DN_No +
                    " tidak dikirim. " + ErrorMessage;

                return 0;
            }

            string transportInfobar = null;
            int transportReturn = SMK069PostShipmentPayload(
                shipmentUrl,
                PayloadJson,
                "Authorization",
                "Bearer " + accessToken,
                "KACS_V1",
                string.Empty,
                timeoutSeconds,
                ref HttpCode,
                ref ResponseJson,
                ref TransportSuccess,
                ref BusinessSuccess,
                ref ErrorMessage,
                ref transportInfobar);

            // Drop token immediately after constructing the request.
            accessToken = null;

            string completionResponse = BuildCompletionResponse(
                ResponseJson,
                ErrorMessage,
                transportReturn);

            int finalCompleteSuccess;
            string finalCompleteInfobar;

            try
            {
                ExecuteCompleteShipmentSend(
                    logRowPointer,
                    HttpCode,
                    completionResponse,
                    BusinessSuccess,
                    out finalCompleteSuccess,
                    out finalCompleteInfobar);
            }
            catch (Exception ex)
            {
                Success = 0;
                ErrorMessage = AppendMessage(
                    ErrorMessage,
                    "Complete Shipment exception: " + ex.Message);
                Infobar =
                    "Shipment DN " + DN_No +
                    " sudah dikirim ke POS tetapi Complete gagal. " +
                    "Periksa outbound log sebelum retry. " + ErrorMessage;
                return 16;
            }

            if (BusinessSuccess == 1 && finalCompleteSuccess != 1)
            {
                Success = 0;
                ErrorMessage = AppendMessage(
                    ErrorMessage,
                    string.IsNullOrWhiteSpace(finalCompleteInfobar)
                        ? "POS menerima Shipment tetapi Complete tidak mengonfirmasi update sukses."
                        : finalCompleteInfobar);
                Infobar = ErrorMessage;
                return 16;
            }

            Success =
                BusinessSuccess == 1 && finalCompleteSuccess == 1
                    ? 1
                    : 0;

            Infobar = BuildOneShipmentInfobar(
                DN_No,
                LogRowPointer,
                Success,
                prepareInfobar,
                transportInfobar,
                finalCompleteInfobar);

            return 0;
        }

        /// <summary>
        /// One-shipment sender with an explicit endpoint and auth header.
        /// This is the method the batch sender calls, and the one to use for UAT
        /// because it never depends on the compiled path constant.
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int SMK069SendOneShipment(
            string DN_No,
            string EndpointUrl,
            string AuthHeaderName,
            string AuthHeaderValue,
            string SuccessMode,
            string SuccessMarker,
            int TimeoutSeconds,
            ref string LogRowPointer,
            ref string PayloadJson,
            ref int HttpCode,
            ref string ResponseJson,
            ref int TransportSuccess,
            ref int BusinessSuccess,
            ref string ErrorMessage,
            ref int Success,
            ref string Infobar)
        {
            LogRowPointer = null;
            PayloadJson = null;
            HttpCode = 0;
            ResponseJson = null;
            TransportSuccess = 0;
            BusinessSuccess = 0;
            ErrorMessage = null;
            Success = 0;
            Infobar = null;

            if (string.IsNullOrWhiteSpace(DN_No))
            {
                ErrorMessage = "DN_No wajib diisi.";
                Infobar = ErrorMessage;
                return 16;
            }

            DN_No = DN_No.Trim();

            Guid logRowPointer;
            int prepareSuccess;
            string prepareInfobar;

            try
            {
                ExecutePrepareShipmentSend(
                    DN_No,
                    EndpointUrl,
                    out logRowPointer,
                    out PayloadJson,
                    out prepareSuccess,
                    out prepareInfobar);
            }
            catch (Exception ex)
            {
                ErrorMessage = "Prepare Shipment exception: " + ex.Message;
                Infobar = ErrorMessage;
                return 16;
            }

            if (prepareSuccess != 1 || logRowPointer == Guid.Empty)
            {
                ErrorMessage = string.IsNullOrWhiteSpace(prepareInfobar)
                    ? "Prepare Shipment gagal."
                    : prepareInfobar;
                Infobar = ErrorMessage;
                return 16;
            }

            LogRowPointer = logRowPointer.ToString();

            string transportInfobar = null;
            int transportReturn = SMK069PostShipmentPayload(
                EndpointUrl,
                PayloadJson,
                AuthHeaderName,
                AuthHeaderValue,
                SuccessMode,
                SuccessMarker,
                TimeoutSeconds,
                ref HttpCode,
                ref ResponseJson,
                ref TransportSuccess,
                ref BusinessSuccess,
                ref ErrorMessage,
                ref transportInfobar);

            string completionResponse = BuildCompletionResponse(
                ResponseJson,
                ErrorMessage,
                transportReturn);

            int completeSuccess;
            string completeInfobar;

            try
            {
                ExecuteCompleteShipmentSend(
                    logRowPointer,
                    HttpCode,
                    completionResponse,
                    BusinessSuccess,
                    out completeSuccess,
                    out completeInfobar);
            }
            catch (Exception ex)
            {
                Success = 0;
                ErrorMessage = AppendMessage(
                    ErrorMessage,
                    "Complete Shipment exception: " + ex.Message);
                Infobar =
                    "Shipment " + DN_No +
                    " sudah melalui Prepare/HTTP tetapi Complete gagal. " +
                    "Periksa outbound log sebelum retry. " + ErrorMessage;
                return 16;
            }

            if (BusinessSuccess == 1 && completeSuccess != 1)
            {
                Success = 0;
                ErrorMessage = AppendMessage(
                    ErrorMessage,
                    string.IsNullOrWhiteSpace(completeInfobar)
                        ? "POS menerima Shipment tetapi Complete tidak mengonfirmasi update sukses."
                        : completeInfobar);
                Infobar = ErrorMessage;
                return 16;
            }

            Success = BusinessSuccess == 1 && completeSuccess == 1 ? 1 : 0;

            Infobar = BuildOneShipmentInfobar(
                DN_No,
                LogRowPointer,
                Success,
                prepareInfobar,
                transportInfobar,
                completeInfobar);

            return 0;
        }

        // =====================================================================
        // Scheduler support - reads policy from SQL
        // =====================================================================

        private void ReadShipmentConfig(
            out int isEnabled,
            out string loginUrl,
            out string endpointUrl,
            out string successMode,
            out int timeoutSeconds,
            out string infobar)
        {
            isEnabled = 0;
            loginUrl = null;
            endpointUrl = null;
            successMode = "KACS_V1";
            timeoutSeconds = DefaultTimeoutSeconds;
            infobar = null;

            InvokeResponseData response = this.Context.Commands.Invoke(
                "ue_SMK069ShipmentTransport",
                "SMK069GetShipmentConfigSp",
                IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value);

            if (response == null || response.Parameters.Count < 7)
            {
                throw new InvalidOperationException(
                    "SMK069GetShipmentConfigSp harus memiliki 7 parameter.");
            }

            infobar = response.Parameters[6].IsNull ? null : response.Parameters[6].Value;

            if (response.IsReturnValueStdError())
            {
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(infobar)
                        ? "SMK069GetShipmentConfigSp gagal."
                        : infobar);
            }

            if (!response.Parameters[0].IsNull)
            {
                isEnabled = response.Parameters[0].GetValue<int>();
            }

            loginUrl = response.Parameters[1].IsNull ? null : response.Parameters[1].Value;
            endpointUrl = response.Parameters[2].IsNull ? null : response.Parameters[2].Value;

            if (!response.Parameters[3].IsNull &&
                !string.IsNullOrWhiteSpace(response.Parameters[3].Value))
            {
                successMode = response.Parameters[3].Value;
            }

            if (!response.Parameters[4].IsNull)
            {
                timeoutSeconds = response.Parameters[4].GetValue<int>();
            }
        }

        private void ReadPendingShipments(
            int maxShipments,
            out string pendingList,
            out int pendingCount,
            out int dueLaterCount,
            out int exhaustedCount,
            out string infobar)
        {
            pendingList = null;
            pendingCount = 0;
            dueLaterCount = 0;
            exhaustedCount = 0;
            infobar = null;

            InvokeResponseData response = this.Context.Commands.Invoke(
                "ue_SMK069ShipmentTransport",
                "SMK069GetPendingShipmentsSp",
                maxShipments > 0 ? (object)maxShipments : IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value);

            if (response == null || response.Parameters.Count < 6)
            {
                throw new InvalidOperationException(
                    "SMK069GetPendingShipmentsSp harus memiliki 6 parameter.");
            }

            infobar = response.Parameters[5].IsNull ? null : response.Parameters[5].Value;

            if (response.IsReturnValueStdError())
            {
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(infobar)
                        ? "SMK069GetPendingShipmentsSp gagal."
                        : infobar);
            }

            pendingList = response.Parameters[1].IsNull ? null : response.Parameters[1].Value;

            if (!response.Parameters[2].IsNull)
            {
                pendingCount = response.Parameters[2].GetValue<int>();
            }

            if (!response.Parameters[3].IsNull)
            {
                dueLaterCount = response.Parameters[3].GetValue<int>();
            }

            if (!response.Parameters[4].IsNull)
            {
                exhaustedCount = response.Parameters[4].GetValue<int>();
            }
        }

        private void RecordShipmentAttempt(
            string dnNo,
            bool isSuccess,
            int httpCode,
            string errorMessage,
            out int attemptCount,
            out int exhausted,
            out string infobar)
        {
            attemptCount = 0;
            exhausted = 0;
            infobar = null;

            InvokeResponseData response = this.Context.Commands.Invoke(
                "ue_SMK069ShipmentTransport",
                "SMK069RecordShipmentAttemptSp",
                dnNo,
                isSuccess ? 1 : 0,
                httpCode,
                string.IsNullOrWhiteSpace(errorMessage)
                    ? IDONull.Value
                    : (object)LimitBody(errorMessage, 1000),
                IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value);

            if (response == null || response.Parameters.Count < 8)
            {
                throw new InvalidOperationException(
                    "SMK069RecordShipmentAttemptSp harus memiliki 8 parameter.");
            }

            infobar = response.Parameters[7].IsNull ? null : response.Parameters[7].Value;

            if (response.IsReturnValueStdError())
            {
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(infobar)
                        ? "SMK069RecordShipmentAttemptSp gagal."
                        : infobar);
            }

            if (!response.Parameters[4].IsNull)
            {
                attemptCount = response.Parameters[4].GetValue<int>();
            }

            if (!response.Parameters[6].IsNull)
            {
                exhausted = response.Parameters[6].GetValue<int>();
            }
        }

        // =====================================================================
        // Existing lifecycle bridges
        // =====================================================================

        private void ExecutePrepareShipmentSend(
            string dnNo,
            string endpointUrl,
            out Guid logRowPointer,
            out string payloadJson,
            out int success,
            out string infobar)
        {
            logRowPointer = Guid.Empty;
            payloadJson = null;
            success = 0;
            infobar = null;

            InvokeResponseData response = this.Context.Commands.Invoke(
                "ue_SMK069ShipmentTransport",
                "SMK069PrepareShipmentSendSp",
                dnNo,
                string.IsNullOrWhiteSpace(endpointUrl)
                    ? IDONull.Value
                    : (object)endpointUrl.Trim(),
                IDONull.Value,
                IDONull.Value,
                IDONull.Value,
                IDONull.Value);

            if (response == null)
            {
                throw new InvalidOperationException(
                    "Prepare Shipment tidak mengembalikan IDO response.");
            }

            if (response.Parameters.Count < 6)
            {
                throw new InvalidOperationException(
                    "Prepare Shipment IDO method harus memiliki 6 parameter.");
            }

            infobar = response.Parameters[5].IsNull
                ? null
                : response.Parameters[5].Value;

            if (response.IsReturnValueStdError())
            {
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(infobar)
                        ? "Prepare Shipment IDO invoke gagal."
                        : infobar);
            }

            if (!response.Parameters[2].IsNull)
            {
                logRowPointer = response.Parameters[2].GetValue<Guid>();
            }

            payloadJson = response.Parameters[3].IsNull
                ? null
                : response.Parameters[3].Value;

            success = response.Parameters[4].IsNull
                ? 0
                : response.Parameters[4].GetValue<int>();
        }

        private void ExecuteCompleteShipmentSend(
            Guid logRowPointer,
            int httpCode,
            string responseJson,
            int isSuccess,
            out int success,
            out string infobar)
        {
            success = 0;
            infobar = null;

            InvokeResponseData response = this.Context.Commands.Invoke(
                "ue_SMK069ShipmentTransport",
                "SMK069CompleteShipmentSendSp",
                logRowPointer,
                httpCode,
                string.IsNullOrEmpty(responseJson)
                    ? IDONull.Value
                    : (object)responseJson,
                isSuccess == 1 ? 1 : 0,
                IDONull.Value,
                IDONull.Value);

            if (response == null)
            {
                throw new InvalidOperationException(
                    "Complete Shipment tidak mengembalikan IDO response.");
            }

            if (response.Parameters.Count < 6)
            {
                throw new InvalidOperationException(
                    "Complete Shipment IDO method harus memiliki 6 parameter.");
            }

            infobar = response.Parameters[5].IsNull
                ? null
                : response.Parameters[5].Value;

            if (response.IsReturnValueStdError())
            {
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(infobar)
                        ? "Complete Shipment IDO invoke gagal."
                        : infobar);
            }

            success = response.Parameters[4].IsNull
                ? 0
                : response.Parameters[4].GetValue<int>();
        }

        private static bool ResolvePosUrls(
            string environmentName,
            out string loginUrl,
            out string shipmentUrl,
            ref string errorMessage)
        {
            loginUrl = null;
            shipmentUrl = null;

            string environment = string.IsNullOrWhiteSpace(environmentName)
                ? "UAT"
                : environmentName.Trim().ToUpperInvariant();

            string baseUrl;
            if (environment == "UAT" || environment == "DEV")
            {
                baseUrl = PosUatBaseUrl;
            }
            else if (environment == "PROD" || environment == "PRODUCTION")
            {
                baseUrl = PosProdBaseUrl;
            }
            else
            {
                errorMessage = "ApiEnvironment harus UAT atau PROD.";
                return false;
            }

            loginUrl = baseUrl + PosLoginPath;
            shipmentUrl = baseUrl + PosShipmentPath;
            return true;
        }

        private static bool TryPosLogin(
            string loginUrl,
            string username,
            string password,
            int timeoutSeconds,
            out int httpCode,
            out string responseBody,
            out string accessToken,
            out string errorMessage)
        {
            httpCode = 0;
            responseBody = null;
            accessToken = null;
            errorMessage = null;

            string requestJson =
                "{\"username\":\"" + JsonEscape(username) +
                "\",\"password\":\"" + JsonEscape(password) + "\"}";

            Uri endpoint;
            string endpointError = null;
            if (!TryValidateEndpoint(loginUrl, out endpoint, ref endpointError))
            {
                errorMessage = endpointError;
                return false;
            }

            try
            {
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(endpoint);
                request.Method = "POST";
                request.ContentType = "application/json; charset=utf-8";
                request.Accept = "application/json";
                request.Timeout = timeoutSeconds * 1000;
                request.ReadWriteTimeout = timeoutSeconds * 1000;
                request.KeepAlive = false;

                byte[] requestBytes = Encoding.UTF8.GetBytes(requestJson);
                request.ContentLength = requestBytes.Length;

                using (Stream requestStream = request.GetRequestStream())
                {
                    requestStream.Write(requestBytes, 0, requestBytes.Length);
                }

                try
                {
                    using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                    {
                        httpCode = (int)response.StatusCode;
                        responseBody = LimitBody(ReadResponseBody(response));
                    }
                }
                catch (WebException ex)
                {
                    HttpWebResponse errorResponse = ex.Response as HttpWebResponse;
                    if (errorResponse != null)
                    {
                        using (errorResponse)
                        {
                            httpCode = (int)errorResponse.StatusCode;
                            responseBody = LimitBody(ReadResponseBody(errorResponse));
                            errorMessage =
                                "POS login HTTP error " +
                                httpCode.ToString(CultureInfo.InvariantCulture) +
                                BuildBodySuffix(SanitizeLoginResponse(responseBody));
                        }
                    }
                    else
                    {
                        errorMessage = "POS login transport gagal: " + ex.Message;
                    }

                    return false;
                }

                if (httpCode != 200)
                {
                    errorMessage =
                        "POS login gagal. HTTP " +
                        httpCode.ToString(CultureInfo.InvariantCulture) +
                        BuildBodySuffix(SanitizeLoginResponse(responseBody));
                    return false;
                }

                Match tokenMatch = Regex.Match(
                    responseBody ?? string.Empty,
                    "\\\"token\\\"\\s*:\\s*\\\"(?<token>[^\\\"]+)\\\"",
                    RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

                if (!tokenMatch.Success ||
                    string.IsNullOrWhiteSpace(tokenMatch.Groups["token"].Value))
                {
                    errorMessage =
                        "POS login HTTP 200 tetapi token tidak ditemukan pada response.";
                    return false;
                }

                accessToken = tokenMatch.Groups["token"].Value;
                return true;
            }
            catch (Exception ex)
            {
                errorMessage = "POS login exception: " + ex.Message;
                return false;
            }
        }

        [IDOMethod(MethodFlags.None, "Infobar")]
        public int SMK069PostShipmentPayload(
            string EndpointUrl,
            string RequestJson,
            string AuthHeaderName,
            string AuthHeaderValue,
            string SuccessMode,
            string SuccessMarker,
            int TimeoutSeconds,
            ref int HttpCode,
            ref string ResponseJson,
            ref int TransportSuccess,
            ref int BusinessSuccess,
            ref string ErrorMessage,
            ref string Infobar)
        {
            HttpCode = 0;
            ResponseJson = null;
            TransportSuccess = 0;
            BusinessSuccess = 0;
            ErrorMessage = null;
            Infobar = null;

            Uri endpoint;
            if (!TryValidateEndpoint(EndpointUrl, out endpoint, ref ErrorMessage))
            {
                Infobar = ErrorMessage;
                return 16;
            }

            if (string.IsNullOrWhiteSpace(RequestJson))
            {
                ErrorMessage = "Shipment RequestJson wajib diisi.";
                Infobar = ErrorMessage;
                return 16;
            }

            string successMode = NormalizeSuccessMode(SuccessMode);
            if (successMode == null)
            {
                ErrorMessage =
                    "SuccessMode tidak valid. Gunakan UNCONFIRMED, MARKER, HTTP_2XX, atau KACS_V1.";
                Infobar = ErrorMessage;
                return 16;
            }

            if (successMode == "MARKER" && string.IsNullOrWhiteSpace(SuccessMarker))
            {
                ErrorMessage = "SuccessMarker wajib diisi bila SuccessMode=MARKER.";
                Infobar = ErrorMessage;
                return 16;
            }

            int timeoutSeconds = NormalizeTimeout(TimeoutSeconds);

            if (!ValidateAuthHeaderName(AuthHeaderName, ref ErrorMessage))
            {
                Infobar = ErrorMessage;
                return 16;
            }

            try
            {
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(endpoint);
                request.Method = "POST";
                request.ContentType = "application/json; charset=utf-8";
                request.Accept = "application/json";
                request.Timeout = timeoutSeconds * 1000;
                request.ReadWriteTimeout = timeoutSeconds * 1000;
                request.KeepAlive = false;

                if (!string.IsNullOrWhiteSpace(AuthHeaderName))
                {
                    request.Headers[AuthHeaderName.Trim()] = AuthHeaderValue ?? string.Empty;
                }

                byte[] requestBytes = Encoding.UTF8.GetBytes(RequestJson);
                request.ContentLength = requestBytes.Length;

                try
                {
                    using (Stream requestStream = request.GetRequestStream())
                    {
                        requestStream.Write(requestBytes, 0, requestBytes.Length);
                    }

                    using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                    {
                        TransportSuccess = 1;
                        HttpCode = (int)response.StatusCode;
                        string body = ReadResponseBody(response);

                        EvaluateBusinessResult(
                            HttpCode,
                            body,
                            successMode,
                            SuccessMarker,
                            ref BusinessSuccess,
                            ref ErrorMessage);

                        ResponseJson = LimitBody(body);
                    }
                }
                catch (WebException ex)
                {
                    HttpWebResponse errorResponse = ex.Response as HttpWebResponse;
                    if (errorResponse != null)
                    {
                        using (errorResponse)
                        {
                            TransportSuccess = 1;
                            HttpCode = (int)errorResponse.StatusCode;
                            string body = ReadResponseBody(errorResponse);
                            ResponseJson = LimitBody(body);
                            BusinessSuccess = 0;
                            ErrorMessage = BuildHttpError(HttpCode, body);
                        }
                    }
                    else
                    {
                        TransportSuccess = 0;
                        BusinessSuccess = 0;
                        ErrorMessage = "HTTP transport gagal: " + ex.Message;
                    }
                }

                Infobar = BuildInfobar(
                    endpoint,
                    HttpCode,
                    TransportSuccess,
                    BusinessSuccess,
                    successMode,
                    ErrorMessage);

                return 0;
            }
            catch (Exception ex)
            {
                TransportSuccess = 0;
                BusinessSuccess = 0;
                ErrorMessage = "Shipment sender exception: " + ex.Message;
                Infobar = ErrorMessage;
                return 0;
            }
        }

        private static int NormalizeTimeout(int timeoutSeconds)
        {
            return timeoutSeconds <= 0
                ? DefaultTimeoutSeconds
                : Math.Min(timeoutSeconds, MaximumTimeoutSeconds);
        }

        private static bool TryValidateEndpoint(
            string endpointUrl,
            out Uri endpoint,
            ref string errorMessage)
        {
            endpoint = null;

            if (string.IsNullOrWhiteSpace(endpointUrl))
            {
                errorMessage = "EndpointUrl wajib diisi.";
                return false;
            }

            if (!Uri.TryCreate(endpointUrl.Trim(), UriKind.Absolute, out endpoint))
            {
                errorMessage = "EndpointUrl bukan absolute URL yang valid.";
                return false;
            }

            if (endpoint.Scheme != Uri.UriSchemeHttps &&
                endpoint.Scheme != Uri.UriSchemeHttp)
            {
                errorMessage = "EndpointUrl harus menggunakan http atau https.";
                return false;
            }

            if (!string.IsNullOrEmpty(endpoint.UserInfo))
            {
                errorMessage =
                    "Credential tidak boleh ditanam di URL.";
                return false;
            }

            return true;
        }

        private static string NormalizeSuccessMode(string successMode)
        {
            string mode = string.IsNullOrWhiteSpace(successMode)
                ? "UNCONFIRMED"
                : successMode.Trim().ToUpperInvariant();

            switch (mode)
            {
                case "UNCONFIRMED":
                case "MARKER":
                case "HTTP_2XX":
                case "KACS_V1":
                    return mode;
                default:
                    return null;
            }
        }

        private static bool ValidateAuthHeaderName(
            string authHeaderName,
            ref string errorMessage)
        {
            if (string.IsNullOrWhiteSpace(authHeaderName))
            {
                return true;
            }

            string name = authHeaderName.Trim();

            if (name.Equals("Content-Type", StringComparison.OrdinalIgnoreCase) ||
                name.Equals("Content-Length", StringComparison.OrdinalIgnoreCase) ||
                name.Equals("Host", StringComparison.OrdinalIgnoreCase) ||
                name.Equals("Connection", StringComparison.OrdinalIgnoreCase))
            {
                errorMessage =
                    "AuthHeaderName tidak boleh memakai reserved HTTP header: " +
                    name + ".";
                return false;
            }

            return true;
        }

        private static string ReadResponseBody(HttpWebResponse response)
        {
            if (response == null)
            {
                return string.Empty;
            }

            Stream stream = response.GetResponseStream();
            if (stream == null)
            {
                return string.Empty;
            }

            using (stream)
            using (StreamReader reader = new StreamReader(stream, Encoding.UTF8, true))
            {
                return reader.ReadToEnd();
            }
        }

        private static void EvaluateBusinessResult(
            int httpCode,
            string responseBody,
            string successMode,
            string successMarker,
            ref int businessSuccess,
            ref string errorMessage)
        {
            bool http2xx = httpCode >= 200 && httpCode <= 299;

            if (!http2xx)
            {
                businessSuccess = 0;
                errorMessage = BuildHttpError(httpCode, responseBody);
                return;
            }

            if (successMode == "KACS_V1")
            {
                bool codeOk =
                    httpCode == 201 &&
                    !string.IsNullOrEmpty(responseBody) &&
                    Regex.IsMatch(
                        responseBody,
                        "\\\"code\\\"\\s*:\\s*200(?:\\D|$)",
                        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

                bool messageOk =
                    !string.IsNullOrEmpty(responseBody) &&
                    Regex.IsMatch(
                        responseBody,
                        "\\\"message\\\"\\s*:\\s*\\\"Success\\\"",
                        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

                businessSuccess = codeOk && messageOk ? 1 : 0;
                errorMessage = businessSuccess == 1
                    ? null
                    : "POS response tidak memenuhi kontrak sukses: HTTP 201 + code 200 + message Success.";
                return;
            }

            if (successMode == "HTTP_2XX")
            {
                businessSuccess = 1;
                errorMessage = null;
                return;
            }

            if (successMode == "MARKER")
            {
                bool markerFound =
                    !string.IsNullOrEmpty(responseBody) &&
                    responseBody.IndexOf(
                        successMarker,
                        StringComparison.OrdinalIgnoreCase) >= 0;

                businessSuccess = markerFound ? 1 : 0;
                errorMessage = markerFound
                    ? null
                    : "HTTP 2xx diterima tetapi POS success marker tidak ditemukan.";
                return;
            }

            businessSuccess = 0;
            errorMessage =
                "HTTP 2xx diterima, tetapi POS success contract belum dikonfirmasi. " +
                "Shipment tidak boleh dianggap posted hanya dari HTTP status.";
        }

        private static string BuildCompletionResponse(
            string responseJson,
            string errorMessage,
            int transportReturn)
        {
            if (!string.IsNullOrWhiteSpace(responseJson))
            {
                return responseJson;
            }

            if (string.IsNullOrWhiteSpace(errorMessage))
            {
                return null;
            }

            return
                "{\"SMK069_TRANSPORT_ERROR\":\"" +
                JsonEscape(errorMessage) +
                "\",\"METHOD_RETURN\":" +
                transportReturn.ToString(CultureInfo.InvariantCulture) +
                "}";
        }

        private static string BuildStageResponse(
            string stage,
            int httpCode,
            string responseBody,
            string errorMessage)
        {
            return
                "{\"STAGE\":\"" + JsonEscape(stage) +
                "\",\"HTTP_CODE\":" +
                httpCode.ToString(CultureInfo.InvariantCulture) +
                ",\"RESPONSE\":\"" +
                JsonEscape(responseBody ?? string.Empty) +
                "\",\"ERROR\":\"" +
                JsonEscape(errorMessage ?? string.Empty) +
                "\"}";
        }

        private static string SanitizeLoginResponse(string responseBody)
        {
            if (string.IsNullOrEmpty(responseBody))
            {
                return responseBody;
            }

            string sanitized = Regex.Replace(
                responseBody,
                "(\\\"token\\\"\\s*:\\s*\\\")[^\\\"]*(\\\")",
                "$1<redacted>$2",
                RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

            sanitized = Regex.Replace(
                sanitized,
                "(\\\"refresh_token\\\"\\s*:\\s*\\\")[^\\\"]*(\\\")",
                "$1<redacted>$2",
                RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

            return sanitized;
        }

        private static string BuildBodySuffix(string body)
        {
            return string.IsNullOrWhiteSpace(body)
                ? string.Empty
                : "; Response=" + LimitBody(body, 2000);
        }

        private static string BuildHttpError(int httpCode, string body)
        {
            return string.Format(
                CultureInfo.InvariantCulture,
                "POS API HTTP error {0}{1}",
                httpCode,
                BuildBodySuffix(body));
        }

        private static string BuildInfobar(
            Uri endpoint,
            int httpCode,
            int transportSuccess,
            int businessSuccess,
            string successMode,
            string errorMessage)
        {
            string summary = string.Format(
                CultureInfo.InvariantCulture,
                "SMK069 Shipment POST. Host={0}; Http={1}; TransportSuccess={2}; " +
                "BusinessSuccess={3}; SuccessMode={4}.",
                endpoint.Host,
                httpCode,
                transportSuccess,
                businessSuccess,
                successMode);

            if (!string.IsNullOrWhiteSpace(errorMessage))
            {
                summary += " " + errorMessage;
            }

            return summary;
        }

        private static string BuildOneShipmentInfobar(
            string dnNo,
            string logRowPointer,
            int success,
            string prepareInfobar,
            string transportInfobar,
            string completeInfobar)
        {
            string summary =
                "SMK069 Shipment DN=" +
                (dnNo ?? string.Empty) +
                "; Log=" +
                (logRowPointer ?? string.Empty) +
                "; Result=" +
                (success == 1 ? "SUCCESS" : "FAILED") +
                ".";

            if (!string.IsNullOrWhiteSpace(transportInfobar))
            {
                summary += " " + transportInfobar;
            }

            if (!string.IsNullOrWhiteSpace(completeInfobar))
            {
                summary += " Complete=" + completeInfobar;
            }
            else if (!string.IsNullOrWhiteSpace(prepareInfobar))
            {
                summary += " Prepare=" + prepareInfobar;
            }

            return summary;
        }

        private static string AppendMessage(string current, string next)
        {
            if (string.IsNullOrWhiteSpace(current))
            {
                return next;
            }

            if (string.IsNullOrWhiteSpace(next))
            {
                return current;
            }

            return current + " | " + next;
        }

        private static string JsonEscape(string value)
        {
            if (value == null)
            {
                return string.Empty;
            }

            StringBuilder escaped = new StringBuilder(value.Length + 16);

            foreach (char c in value)
            {
                switch (c)
                {
                    case '\\':
                        escaped.Append("\\\\");
                        break;
                    case '"':
                        escaped.Append("\\\"");
                        break;
                    case '\r':
                        escaped.Append("\\r");
                        break;
                    case '\n':
                        escaped.Append("\\n");
                        break;
                    case '\t':
                        escaped.Append("\\t");
                        break;
                    default:
                        if (c < 32)
                        {
                            escaped.Append(
                                "\\u" +
                                ((int)c).ToString(
                                    "x4",
                                    CultureInfo.InvariantCulture));
                        }
                        else
                        {
                            escaped.Append(c);
                        }
                        break;
                }
            }

            return escaped.ToString();
        }

        private static string LimitBody(string body)
        {
            return LimitBody(body, MaximumReturnedBodyChars);
        }

        private static string LimitBody(string body, int maximumChars)
        {
            if (string.IsNullOrEmpty(body) || body.Length <= maximumChars)
            {
                return body;
            }

            return body.Substring(0, maximumChars) +
                   "\n...[response truncated by SMK069 shipment sender]";
        }
    }
}
