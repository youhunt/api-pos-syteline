using System;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using Mongoose.IDO;

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
