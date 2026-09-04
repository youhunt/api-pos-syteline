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
    /// <summary>
    /// Server-side transport for SMK069 Shipment outbound.
    ///
    /// Production concept:
    /// DN_No -> Prepare/build payload -> KACS login -> Shipment POST -> Complete.
    ///
    /// The KACS URL and Authorization header are transport concerns and are
    /// never inserted into the Shipment business JSON payload.
    /// </summary>
    [IDOExtensionClass("ue_SMK069ShipmentTransport")]
    public class SMK069ShipmentTransportExtension : IDOExtensionClass
    {
        private const int DefaultTimeoutSeconds = 60;
        private const int MaximumTimeoutSeconds = 300;
        private const int MaximumReturnedBodyChars = 1048576;

        private const string KacsUatBaseUrl = "https://api-uat.pizzahut.co.id";
        private const string KacsProdBaseUrl = "https://api-prod.pizzahut.co.id";
        private const string KacsLoginPath = "/service-auth/login-once";
        private const string KacsShipmentPath = "/inventory-phi/v1/kacs_dn";

        /// <summary>
        /// Simple KACS orchestration.
        ///
        /// Inputs:
        /// - DN_No
        /// - ApiEnvironment: UAT or PROD
        /// - Username / Password: runtime credentials, never logged
        /// - TimeoutSeconds
        ///
        /// Outputs contain the Shipment payload and final KACS Shipment response.
        /// The access token is deliberately never returned or logged.
        ///
        /// Keep this IDO method NON-TRANSACTIONAL because it performs external HTTP.
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int SMK069SendOneShipmentKacs(
            long DN_No,
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

            string loginUrl;
            string shipmentUrl;
            if (!ResolveKacsUrls(ApiEnvironment, out loginUrl, out shipmentUrl, ref ErrorMessage))
            {
                Infobar = ErrorMessage;
                return 16;
            }

            if (string.IsNullOrWhiteSpace(Username) ||
                string.IsNullOrWhiteSpace(Password))
            {
                ErrorMessage = "KACS Username dan Password wajib diisi saat runtime.";
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

            bool loginOk = TryKacsLogin(
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
                    ? "KACS login gagal."
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
                        "Complete Shipment exception setelah KACS login gagal: " + ex.Message);
                    Infobar = ErrorMessage;
                    return 16;
                }

                Infobar =
                    "KACS login gagal; Shipment DN " +
                    DN_No.ToString(CultureInfo.InvariantCulture) +
                    " tidak dikirim. " +
                    ErrorMessage;

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
                    "Shipment DN " +
                    DN_No.ToString(CultureInfo.InvariantCulture) +
                    " sudah dikirim ke KACS tetapi Complete gagal. " +
                    "Periksa outbound log sebelum retry. " +
                    ErrorMessage;
                return 16;
            }

            if (BusinessSuccess == 1 && finalCompleteSuccess != 1)
            {
                Success = 0;
                ErrorMessage = AppendMessage(
                    ErrorMessage,
                    string.IsNullOrWhiteSpace(finalCompleteInfobar)
                        ? "KACS menerima Shipment tetapi Complete tidak mengonfirmasi update sukses."
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
        /// Existing generic one-Shipment method kept for diagnostics/backward compatibility.
        /// Endpoint/auth are method parameters, not Shipment JSON fields.
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

        private static bool ResolveKacsUrls(
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
                baseUrl = KacsUatBaseUrl;
            }
            else if (environment == "PROD" || environment == "PRODUCTION")
            {
                baseUrl = KacsProdBaseUrl;
            }
            else
            {
                errorMessage = "ApiEnvironment harus UAT atau PROD.";
                return false;
            }

            loginUrl = baseUrl + KacsLoginPath;
            shipmentUrl = baseUrl + KacsShipmentPath;
            return true;
        }

        private static bool TryKacsLogin(
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
                                "KACS login HTTP error " +
                                httpCode.ToString(CultureInfo.InvariantCulture) +
                                BuildBodySuffix(SanitizeLoginResponse(responseBody));
                        }
                    }
                    else
                    {
                        errorMessage = "KACS login transport gagal: " + ex.Message;
                    }

                    return false;
                }

                if (httpCode != 200)
                {
                    errorMessage =
                        "KACS login gagal. HTTP " +
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
                        "KACS login HTTP 200 tetapi token tidak ditemukan pada response.";
                    return false;
                }

                accessToken = tokenMatch.Groups["token"].Value;
                return true;
            }
            catch (Exception ex)
            {
                errorMessage = "KACS login exception: " + ex.Message;
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
                    : "KACS response tidak memenuhi kontrak sukses: HTTP 201 + code 200 + message Success.";
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
