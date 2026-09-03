using System;
using System.Data;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using Mongoose.IDO;
using Mongoose.IDO.DataAccess;

namespace SMK069Shipment
{
    /// <summary>
    /// Server-side HTTP transport foundation for SMK069 Shipment outbound.
    ///
    /// This class intentionally does not update shipment_mst or the outbound log.
    /// The stable SQL contract remains:
    ///   Build -> Prepare -> HTTP -> Complete
    ///
    /// A higher-level one-shipment orchestrator will call this transport between
    /// SMK069PrepareShipmentSendSp and SMK069CompleteShipmentSendSp after the
    /// exact tenant IDO/SP parameter metadata is confirmed.
    /// </summary>
    [IDOExtensionClass("ue_SMK069ShipmentTransport")]
    public class SMK069ShipmentTransportExtension : IDOExtensionClass
    {
        private const int DefaultTimeoutSeconds = 60;
        private const int MaximumTimeoutSeconds = 300;
        private const int MaximumReturnedBodyChars = 1048576;

        /// <summary>
        /// Executes one complete Shipment outbound attempt:
        /// Prepare -> HTTP POST -> Complete.
        ///
        /// Important:
        /// - this IDO method must be configured as NON-TRANSACTIONAL because it
        ///   performs an external HTTP call between two database operations;
        /// - the stable Shipment stored procedures remain the source of truth
        ///   for Site scoping, log lifecycle and shipment_mst posted flags;
        /// - a handled POS/transport failure returns method code 0 with
        ///   Success=0 after Complete has persisted the failed attempt.
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int SMK069SendOneShipment(
            long DN_No,
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
                    "Shipment " + DN_No.ToString(CultureInfo.InvariantCulture) +
                    " sudah melalui Prepare/HTTP tetapi Complete gagal. " +
                    "Periksa outbound log sebelum retry. " + ErrorMessage;
                return 16;
            }

            if (completeSuccess != 1)
            {
                Success = 0;
                ErrorMessage = AppendMessage(
                    ErrorMessage,
                    string.IsNullOrWhiteSpace(completeInfobar)
                        ? "Complete Shipment mengembalikan Success=0."
                        : completeInfobar);
                Infobar = ErrorMessage;
                return 16;
            }

            Success = BusinessSuccess == 1 ? 1 : 0;

            Infobar = BuildOneShipmentInfobar(
                DN_No,
                LogRowPointer,
                Success,
                prepareInfobar,
                transportInfobar,
                completeInfobar);

            // Business/HTTP failure is a handled attempt. Complete has already
            // persisted log E and left shipment_mst pending.
            return 0;
        }

        private void ExecutePrepareShipmentSend(
            long dnNo,
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

            using (ApplicationDB appDB = this.CreateApplicationDB())
            using (IDbCommand command = appDB.Connection.CreateCommand())
            {
                command.CommandType = CommandType.StoredProcedure;
                command.CommandText = "dbo.SMK069PrepareShipmentSendSp";

                AddParameter(
                    command,
                    "@DN_No",
                    DbType.Int64,
                    ParameterDirection.Input,
                    dnNo,
                    0);

                AddParameter(
                    command,
                    "@EndpointUrl",
                    DbType.String,
                    ParameterDirection.Input,
                    string.IsNullOrWhiteSpace(endpointUrl)
                        ? (object)DBNull.Value
                        : endpointUrl.Trim(),
                    1000);

                IDbDataParameter logParameter = AddParameter(
                    command,
                    "@LogRowPointer",
                    DbType.Guid,
                    ParameterDirection.Output,
                    DBNull.Value,
                    0);

                IDbDataParameter payloadParameter = AddParameter(
                    command,
                    "@PayloadJson",
                    DbType.String,
                    ParameterDirection.Output,
                    DBNull.Value,
                    -1);

                IDbDataParameter successParameter = AddParameter(
                    command,
                    "@Success",
                    DbType.Int32,
                    ParameterDirection.Output,
                    DBNull.Value,
                    0);

                IDbDataParameter infobarParameter = AddParameter(
                    command,
                    "@Infobar",
                    DbType.String,
                    ParameterDirection.Output,
                    DBNull.Value,
                    4000);

                command.ExecuteNonQuery();

                if (logParameter.Value != null &&
                    logParameter.Value != DBNull.Value)
                {
                    logRowPointer = (Guid)logParameter.Value;
                }

                payloadJson = DbString(payloadParameter.Value);
                success = DbInt32(successParameter.Value);
                infobar = DbString(infobarParameter.Value);
            }
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

            using (ApplicationDB appDB = this.CreateApplicationDB())
            using (IDbCommand command = appDB.Connection.CreateCommand())
            {
                command.CommandType = CommandType.StoredProcedure;
                command.CommandText = "dbo.SMK069CompleteShipmentSendSp";

                AddParameter(
                    command,
                    "@LogRowPointer",
                    DbType.Guid,
                    ParameterDirection.Input,
                    logRowPointer,
                    0);

                AddParameter(
                    command,
                    "@HttpCode",
                    DbType.Int32,
                    ParameterDirection.Input,
                    httpCode,
                    0);

                AddParameter(
                    command,
                    "@ResponseJson",
                    DbType.String,
                    ParameterDirection.Input,
                    string.IsNullOrEmpty(responseJson)
                        ? (object)DBNull.Value
                        : responseJson,
                    -1);

                AddParameter(
                    command,
                    "@IsSuccess",
                    DbType.Int32,
                    ParameterDirection.Input,
                    isSuccess == 1 ? 1 : 0,
                    0);

                IDbDataParameter successParameter = AddParameter(
                    command,
                    "@Success",
                    DbType.Int32,
                    ParameterDirection.Output,
                    DBNull.Value,
                    0);

                IDbDataParameter infobarParameter = AddParameter(
                    command,
                    "@Infobar",
                    DbType.String,
                    ParameterDirection.Output,
                    DBNull.Value,
                    4000);

                command.ExecuteNonQuery();

                success = DbInt32(successParameter.Value);
                infobar = DbString(infobarParameter.Value);
            }
        }

        private static IDbDataParameter AddParameter(
            IDbCommand command,
            string name,
            DbType dbType,
            ParameterDirection direction,
            object value,
            int size)
        {
            IDbDataParameter parameter = command.CreateParameter();
            parameter.ParameterName = name;
            parameter.DbType = dbType;
            parameter.Direction = direction;

            if (size != 0)
            {
                parameter.Size = size;
            }

            if (direction == ParameterDirection.Input ||
                direction == ParameterDirection.InputOutput)
            {
                parameter.Value = value ?? DBNull.Value;
            }

            command.Parameters.Add(parameter);
            return parameter;
        }

        private static string DbString(object value)
        {
            return value == null || value == DBNull.Value
                ? null
                : Convert.ToString(value, CultureInfo.InvariantCulture);
        }

        private static int DbInt32(object value)
        {
            if (value == null || value == DBNull.Value)
            {
                return 0;
            }

            return Convert.ToInt32(value, CultureInfo.InvariantCulture);
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

        private static string BuildOneShipmentInfobar(
            long dnNo,
            string logRowPointer,
            int success,
            string prepareInfobar,
            string transportInfobar,
            string completeInfobar)
        {
            string summary =
                "SMK069 Shipment DN=" +
                dnNo.ToString(CultureInfo.InvariantCulture) +
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
                    "SuccessMode tidak valid. Gunakan UNCONFIRMED, MARKER, atau HTTP_2XX.";
                Infobar = ErrorMessage;
                return 16;
            }

            if (successMode == "MARKER" && string.IsNullOrWhiteSpace(SuccessMarker))
            {
                ErrorMessage = "SuccessMarker wajib diisi bila SuccessMode=MARKER.";
                Infobar = ErrorMessage;
                return 16;
            }

            int timeoutSeconds = TimeoutSeconds <= 0
                ? DefaultTimeoutSeconds
                : Math.Min(TimeoutSeconds, MaximumTimeoutSeconds);

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

                using (Stream requestStream = request.GetRequestStream())
                {
                    requestStream.Write(requestBytes, 0, requestBytes.Length);
                }

                try
                {
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

                // A transport/business failure is returned as handled output (0), not
                // a method exception, so the caller can still execute Complete with
                // Success=0 and persist the failed attempt.
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
                    "Credential tidak boleh ditanam di URL. Gunakan AuthHeaderName/AuthHeaderValue.";
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
                    "AuthHeaderName tidak boleh memakai reserved HTTP header: " + name + ".";
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

            // Conservative default while the POS business-response contract is open.
            businessSuccess = 0;
            errorMessage =
                "HTTP 2xx diterima, tetapi POS success contract belum dikonfirmasi. " +
                "Shipment tidak boleh dianggap posted hanya dari HTTP status.";
        }

        private static string BuildHttpError(int httpCode, string body)
        {
            string suffix = string.IsNullOrWhiteSpace(body)
                ? string.Empty
                : "; Response=" + LimitBody(body, 2000);

            return string.Format(
                CultureInfo.InvariantCulture,
                "POS API HTTP error {0}{1}",
                httpCode,
                suffix);
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
