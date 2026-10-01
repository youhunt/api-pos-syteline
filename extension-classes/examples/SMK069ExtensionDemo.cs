using System;
using System.IO;
using System.Net;
using System.Text;
using Mongoose.IDO;
using Mongoose.IDO.Protocol;

namespace SMK069Test
{
    /// <summary>
    /// Contoh Extension Class sederhana untuk belajar/testing.
    ///
    /// IDO target:
    ///   ue_SMK069Test
    ///
    /// Tujuan:
    ///   1. Method dipanggil langsung.
    ///   2. Method dipanggil dan mengembalikan nilai.
    ///   3. Method Extension memanggil Stored Procedure tanpa output bisnis.
    ///   4. Method Extension memanggil Stored Procedure dan mengambil output.
    ///
    /// Tidak menggunakan System.Data.
    /// Pemanggilan SP dilakukan melalui Context.Commands.Invoke ke IDO method.
    /// </summary>
    [IDOExtensionClass("ue_SMK069Test")]
    public class SMK069TestExtension : IDOExtensionClass
    {
        /// <summary>
        /// Contoh 1:
        /// Method paling sederhana. Tinggal dipanggil.
        ///
        /// Expected:
        ///   ReturnValue = 0
        ///   Infobar     = "DemoPing berhasil dipanggil."
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int DemoPing(ref string Infobar)
        {
            Infobar = "DemoPing berhasil dipanggil.";
            return 0;
        }

        /// <summary>
        /// Contoh 2:
        /// Method menerima input dan memberikan nilai balik melalui parameter Result.
        ///
        /// Input:
        ///   Text = "Yohan"
        ///
        /// Output:
        ///   Result  = "Halo Yohan"
        ///   Infobar = "DemoEcho selesai."
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int DemoEcho(
            string Text,
            ref string Result,
            ref string Infobar)
        {
            Result = "Halo " + (Text ?? string.Empty);
            Infobar = "DemoEcho selesai.";
            return 0;
        }

        /// <summary>
        /// Contoh 3:
        /// Extension Class memanggil Stored Procedure.
        ///
        /// Stored Procedure tersebut didaftarkan pada IDO yang sama sebagai:
        ///   SMK069DemoSimpleSp
        ///
        /// SP tidak mempunyai parameter/output bisnis.
        /// Extension hanya memastikan invoke berhasil.
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int DemoCallSp(ref string Infobar)
        {
            try
            {
                InvokeResponseData response = this.Context.Commands.Invoke(
                    "ue_SMK069Test",
                    "SMK069DemoSimpleSp");

                if (response == null)
                {
                    Infobar = "Tidak ada response dari SMK069DemoSimpleSp.";
                    return 16;
                }

                if (response.IsReturnValueStdError())
                {
                    Infobar = "SMK069DemoSimpleSp mengembalikan error.";
                    return 16;
                }

                Infobar = "SMK069DemoSimpleSp berhasil dipanggil dari Extension Class.";
                return 0;
            }
            catch (Exception ex)
            {
                Infobar = "DemoCallSp gagal: " + ex.Message;
                return 16;
            }
        }

        /// <summary>
        /// Contoh 4:
        /// Extension Class memanggil Stored Procedure dan mengambil nilai OUTPUT.
        ///
        /// Stored Procedure:
        ///   SMK069DemoAddNumbersSp
        ///
        /// Input:
        ///   A = 10
        ///   B = 20
        ///
        /// Output:
        ///   Total   = 30
        ///   Infobar = pesan dari SP
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int DemoCallSpGetValue(
            int A,
            int B,
            ref int Total,
            ref string Infobar)
        {
            Total = 0;
            Infobar = null;

            try
            {
                InvokeResponseData response = this.Context.Commands.Invoke(
                    "ue_SMK069Test",
                    "SMK069DemoAddNumbersSp",
                    A,
                    B,
                    IDONull.Value,
                    IDONull.Value);

                if (response == null || response.Parameters.Count < 4)
                {
                    Infobar = "Response SMK069DemoAddNumbersSp tidak lengkap.";
                    return 16;
                }

                string spInfobar = response.Parameters[3].IsNull
                    ? null
                    : response.Parameters[3].Value;

                if (response.IsReturnValueStdError())
                {
                    Infobar = string.IsNullOrWhiteSpace(spInfobar)
                        ? "SMK069DemoAddNumbersSp mengembalikan error."
                        : spInfobar;

                    return 16;
                }

                if (!response.Parameters[2].IsNull)
                {
                    Total = response.Parameters[2].GetValue<int>();
                }

                Infobar = string.IsNullOrWhiteSpace(spInfobar)
                    ? "SP berhasil dipanggil."
                    : spInfobar;

                return 0;
            }
            catch (Exception ex)
            {
                Infobar = "DemoCallSpGetValue gagal: " + ex.Message;
                return 16;
            }
        }

        /// <summary>
        /// Contoh 5:
        /// HTTP GET sederhana.
        /// URL diberikan sebagai input supaya bisa diarahkan ke endpoint test.
        /// Untuk keamanan demo ini hanya menerima HTTPS.
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int TestApiGet(
            string Url,
            ref int HttpCode,
            ref string ResponseBody,
            ref string Infobar)
        {
            HttpCode = 0;
            ResponseBody = null;
            Infobar = null;

            Uri endpoint;
            string validationError = null;

            if (!TryValidateHttpsUrl(Url, out endpoint, ref validationError))
            {
                Infobar = validationError;
                return 16;
            }

            try
            {
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(endpoint);
                request.Method = "GET";
                request.Accept = "application/json";
                request.Timeout = 30000;
                request.ReadWriteTimeout = 30000;
                request.KeepAlive = false;

                try
                {
                    using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                    {
                        HttpCode = (int)response.StatusCode;
                        ResponseBody = ReadResponseBody(response);
                    }
                }
                catch (WebException ex)
                {
                    HttpWebResponse errorResponse = ex.Response as HttpWebResponse;

                    if (errorResponse != null)
                    {
                        using (errorResponse)
                        {
                            HttpCode = (int)errorResponse.StatusCode;
                            ResponseBody = ReadResponseBody(errorResponse);
                        }

                        Infobar = "HTTP GET gagal. HTTP " + HttpCode.ToString();
                        return 16;
                    }

                    Infobar = "HTTP GET transport gagal: " + ex.Message;
                    return 16;
                }

                if (HttpCode < 200 || HttpCode >= 300)
                {
                    Infobar = "HTTP GET selesai tetapi status bukan 2xx. HTTP " + HttpCode.ToString();
                    return 16;
                }

                Infobar = "HTTP GET berhasil. HTTP " + HttpCode.ToString();
                return 0;
            }
            catch (Exception ex)
            {
                Infobar = "TestApiGet exception: " + ex.Message;
                return 16;
            }
        }

        /// <summary>
        /// Contoh 6:
        /// HTTP POST JSON sederhana.
        /// Tidak menggunakan credential/token supaya aman untuk belajar.
        /// </summary>
        [IDOMethod(MethodFlags.None, "Infobar")]
        public int TestApiPost(
            string Url,
            string RequestJson,
            ref int HttpCode,
            ref string ResponseBody,
            ref string Infobar)
        {
            HttpCode = 0;
            ResponseBody = null;
            Infobar = null;

            Uri endpoint;
            string validationError = null;

            if (!TryValidateHttpsUrl(Url, out endpoint, ref validationError))
            {
                Infobar = validationError;
                return 16;
            }

            if (string.IsNullOrWhiteSpace(RequestJson))
            {
                Infobar = "RequestJson wajib diisi.";
                return 16;
            }

            try
            {
                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(endpoint);
                request.Method = "POST";
                request.ContentType = "application/json; charset=utf-8";
                request.Accept = "application/json";
                request.Timeout = 30000;
                request.ReadWriteTimeout = 30000;
                request.KeepAlive = false;

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
                        HttpCode = (int)response.StatusCode;
                        ResponseBody = ReadResponseBody(response);
                    }
                }
                catch (WebException ex)
                {
                    HttpWebResponse errorResponse = ex.Response as HttpWebResponse;

                    if (errorResponse != null)
                    {
                        using (errorResponse)
                        {
                            HttpCode = (int)errorResponse.StatusCode;
                            ResponseBody = ReadResponseBody(errorResponse);
                        }

                        Infobar = "HTTP POST gagal. HTTP " + HttpCode.ToString();
                        return 16;
                    }

                    Infobar = "HTTP POST transport gagal: " + ex.Message;
                    return 16;
                }

                if (HttpCode < 200 || HttpCode >= 300)
                {
                    Infobar = "HTTP POST selesai tetapi status bukan 2xx. HTTP " + HttpCode.ToString();
                    return 16;
                }

                Infobar = "HTTP POST berhasil. HTTP " + HttpCode.ToString();
                return 0;
            }
            catch (Exception ex)
            {
                Infobar = "TestApiPost exception: " + ex.Message;
                return 16;
            }
        }

        private static bool TryValidateHttpsUrl(
            string Url,
            out Uri Endpoint,
            ref string ErrorMessage)
        {
            Endpoint = null;

            if (string.IsNullOrWhiteSpace(Url))
            {
                ErrorMessage = "URL wajib diisi.";
                return false;
            }

            Uri parsed;
            if (!Uri.TryCreate(Url.Trim(), UriKind.Absolute, out parsed))
            {
                ErrorMessage = "URL tidak valid.";
                return false;
            }

            if (!string.Equals(parsed.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
            {
                ErrorMessage = "Demo ini hanya menerima HTTPS.";
                return false;
            }

            Endpoint = parsed;
            return true;
        }

        private static string ReadResponseBody(HttpWebResponse Response)
        {
            if (Response == null)
            {
                return null;
            }

            Stream responseStream = Response.GetResponseStream();
            if (responseStream == null)
            {
                return null;
            }

            using (responseStream)
            using (StreamReader reader = new StreamReader(
                responseStream,
                Encoding.UTF8))
            {
                return reader.ReadToEnd();
            }
        }

    }
}
