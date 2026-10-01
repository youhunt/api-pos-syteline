using System;
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
    }
}
