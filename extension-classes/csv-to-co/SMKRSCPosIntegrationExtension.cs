using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using Mongoose.IDO;
using Mongoose.IDO.Protocol;

namespace SMKRSCPos
{
    [IDOExtensionClass("ue_SMKRSCPosIntegration")]
    public class SMKRSCPosIntegrationExtension : IDOExtensionClass
    {
        private const string MinimalProfile = "POS_MINIMAL_V1";
        private const string MinimalHeader = "business_date,trans_num,pos_item_code,pos_qty,total_amt";

        [IDOMethod(MethodFlags.None, "Infobar")]
        public int ue_ValidateAttachedCsv(
            string InboundId,
            string DocumentName,
            string ProfileCode,
            ref int RowCount,
            ref int ValidCount,
            ref int ErrorCount,
            ref string PeriodStart,
            ref string PeriodEnd,
            ref int TransCount,
            ref decimal TotalAmt,
            ref string Infobar)
        {
            RowCount = 0;
            ValidCount = 0;
            ErrorCount = 0;
            PeriodStart = string.Empty;
            PeriodEnd = string.Empty;
            TransCount = 0;
            TotalAmt = 0m;
            Infobar = null;

            Guid inboundGuid;
            if (!Guid.TryParse(InboundId, out inboundGuid))
            {
                Infobar = "InboundId tidak valid.";
                return 16;
            }

            DocumentName = string.IsNullOrWhiteSpace(DocumentName)
                ? "POS_MINIMAL_V1"
                : DocumentName.Trim();

            ProfileCode = string.IsNullOrWhiteSpace(ProfileCode)
                ? MinimalProfile
                : ProfileCode.Trim();

            if (!string.Equals(ProfileCode, MinimalProfile, StringComparison.OrdinalIgnoreCase))
            {
                Infobar = "Profile CSV belum didukung: " + ProfileCode;
                return 16;
            }

            try
            {
                LoadCollectionResponseData inbound = this.Context.Commands.LoadCollection(
                    "ue_SMKRSCPosInbounds",
                    "InboundId,RowPointer,RequestId,SourceReference,Stat",
                    "InboundId = '" + inboundGuid.ToString() + "'",
                    string.Empty,
                    1);

                if (inbound.Items.Count != 1)
                {
                    Infobar = "Inbound tidak ditemukan: " + inboundGuid.ToString();
                    return 16;
                }

                Guid rowPointer = inbound[0, "RowPointer"].GetValue<Guid>();
                string documentFilter =
                    "TableRowPointer = '" + rowPointer.ToString() + "'" +
                    " AND DocumentName = N'" + EscapeFilter(DocumentName) + "'";

                LoadCollectionResponseData documents = this.Context.Commands.LoadCollection(
                    "DocumentObjectAndRefViews",
                    "DocumentObject,DocumentName,StorageMethod,TableName,TableRowPointer",
                    documentFilter,
                    string.Empty,
                    1);

                if (documents.Items.Count != 1 || documents[0, "DocumentObject"].IsNull)
                {
                    Infobar = "Attachment tidak ditemukan atau tidak memiliki isi: " + DocumentName;
                    return 16;
                }

                string base64 = documents[0, "DocumentObject"].Value;
                byte[] bytes = DecodeBase64(base64);
                string csv = Encoding.UTF8.GetString(bytes);

                if (csv.Length > 0 && csv[0] == '\uFEFF')
                {
                    csv = csv.Substring(1);
                }

                ValidationResult result = ValidateMinimalCsv(csv);

                RowCount = result.RowCount;
                ValidCount = result.ValidCount;
                ErrorCount = result.Errors.Count;
                PeriodStart = result.PeriodStart.HasValue
                    ? result.PeriodStart.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                    : string.Empty;
                PeriodEnd = result.PeriodEnd.HasValue
                    ? result.PeriodEnd.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                    : string.Empty;
                TransCount = result.TransactionKeys.Count;
                TotalAmt = result.TotalAmount;

                bool valid = result.Errors.Count == 0 && result.RowCount > 0;
                string summary = BuildSummary(result, valid);

                UpdateInboundValidationResult(
                    inbound.Items[0].ItemID,
                    rowPointer,
                    DocumentName,
                    bytes.LongLength,
                    result,
                    valid,
                    summary);

                Infobar = summary;
                return 0;
            }
            catch (FormatException ex)
            {
                Infobar = "DocumentObject bukan Base64 yang valid: " + ex.Message;
                return 16;
            }
            catch (Exception ex)
            {
                Infobar = "ValidateAttachedCsv gagal: " + ex.Message;
                return 16;
            }
        }

        private void UpdateInboundValidationResult(
            string itemId,
            Guid rowPointer,
            string documentName,
            long contentLength,
            ValidationResult result,
            bool valid,
            string summary)
        {
            UpdateCollectionRequestData request = new UpdateCollectionRequestData("ue_SMKRSCPosInbounds");
            request.RefreshAfterUpdate = true;

            IDOUpdateItem update = new IDOUpdateItem(UpdateAction.Update, itemId);
            update.Properties.Add("StorageMode", "E", true);
            update.Properties.Add(
                "PayloadLocation",
                "DOC:ue_SMKRSCPosInbounds:" + rowPointer.ToString() + ":" + documentName,
                true);
            update.Properties.Add("ContentLength", contentLength, true);
            update.Properties.Add("ParsedDate", DateTime.Now, true);
            update.Properties.Add("RowCount", result.RowCount, true);
            update.Properties.Add("AcceptedCount", result.ValidCount, true);
            update.Properties.Add("RejectedCount", result.Errors.Count, true);
            update.Properties.Add("Stat", valid ? "P" : "E", true);
            update.Properties.Add("ResponseCode", valid ? 200 : 422, true);
            update.Properties.Add("ResponseMessage", summary, true);
            update.Properties.Add("ErrorMsg", valid ? null : JoinErrors(result.Errors, 10), true);

            request.Items.Add(update);
            this.Context.Commands.UpdateCollection(request);
        }

        private static ValidationResult ValidateMinimalCsv(string csv)
        {
            ValidationResult result = new ValidationResult();
            string normalized = (csv ?? string.Empty)
                .Replace("\r\n", "\n")
                .Replace('\r', '\n');

            string[] lines = normalized.Split(new[] { '\n' }, StringSplitOptions.None);
            if (lines.Length == 0 || string.IsNullOrWhiteSpace(lines[0]))
            {
                result.Errors.Add("File CSV kosong.");
                return result;
            }

            string actualHeader = string.Join(",", ParseCsvLine(lines[0])).Trim();
            if (!string.Equals(actualHeader, MinimalHeader, StringComparison.OrdinalIgnoreCase))
            {
                result.Errors.Add(
                    "Header tidak sesuai. Expected: " + MinimalHeader + "; Actual: " + actualHeader);
                return result;
            }

            for (int i = 1; i < lines.Length; i++)
            {
                string line = lines[i];
                if (string.IsNullOrWhiteSpace(line))
                {
                    continue;
                }

                result.RowCount++;
                int physicalRow = i + 1;
                List<string> fields = ParseCsvLine(line);

                if (fields.Count != 5)
                {
                    result.Errors.Add(
                        "Baris " + physicalRow.ToString(CultureInfo.InvariantCulture) +
                        ": jumlah kolom harus 5, ditemukan " +
                        fields.Count.ToString(CultureInfo.InvariantCulture) + ".");
                    continue;
                }

                string businessDateText = fields[0].Trim();
                string transNum = fields[1].Trim();
                string itemCode = fields[2].Trim();
                string qtyText = fields[3].Trim();
                string amountText = fields[4].Trim();

                DateTime businessDate;
                decimal qty;
                decimal amount;
                List<string> rowErrors = new List<string>();

                if (!DateTime.TryParseExact(
                        businessDateText,
                        "yyyy-MM-dd",
                        CultureInfo.InvariantCulture,
                        DateTimeStyles.None,
                        out businessDate))
                {
                    rowErrors.Add("business_date harus yyyy-MM-dd");
                }

                if (string.IsNullOrWhiteSpace(transNum))
                {
                    rowErrors.Add("trans_num wajib diisi");
                }

                if (string.IsNullOrWhiteSpace(itemCode))
                {
                    rowErrors.Add("pos_item_code wajib diisi");
                }

                if (!TryParseDecimal(qtyText, out qty))
                {
                    rowErrors.Add("pos_qty harus numerik");
                }
                else if (qty <= 0m)
                {
                    rowErrors.Add("pos_qty harus lebih dari 0");
                }

                if (!TryParseDecimal(amountText, out amount))
                {
                    rowErrors.Add("total_amt harus numerik");
                }
                else if (amount < 0m)
                {
                    rowErrors.Add("total_amt tidak boleh negatif");
                }

                if (rowErrors.Count > 0)
                {
                    result.Errors.Add(
                        "Baris " + physicalRow.ToString(CultureInfo.InvariantCulture) +
                        ": " + string.Join("; ", rowErrors.ToArray()));
                    continue;
                }

                result.ValidCount++;
                result.TotalAmount += amount;
                result.TransactionKeys[businessDateText + "|" + transNum] = true;

                if (!result.PeriodStart.HasValue || businessDate < result.PeriodStart.Value)
                {
                    result.PeriodStart = businessDate;
                }

                if (!result.PeriodEnd.HasValue || businessDate > result.PeriodEnd.Value)
                {
                    result.PeriodEnd = businessDate;
                }
            }

            if (result.RowCount == 0)
            {
                result.Errors.Add("CSV tidak memiliki baris data.");
            }

            return result;
        }

        private static List<string> ParseCsvLine(string line)
        {
            List<string> fields = new List<string>();
            StringBuilder current = new StringBuilder();
            bool insideQuotes = false;

            for (int i = 0; i < (line ?? string.Empty).Length; i++)
            {
                char c = line[i];

                if (c == '"')
                {
                    if (insideQuotes && i + 1 < line.Length && line[i + 1] == '"')
                    {
                        current.Append('"');
                        i++;
                    }
                    else
                    {
                        insideQuotes = !insideQuotes;
                    }
                }
                else if (c == ',' && !insideQuotes)
                {
                    fields.Add(current.ToString());
                    current.Length = 0;
                }
                else
                {
                    current.Append(c);
                }
            }

            fields.Add(current.ToString());
            return fields;
        }

        private static bool TryParseDecimal(string value, out decimal result)
        {
            return decimal.TryParse(
                value,
                NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint,
                CultureInfo.InvariantCulture,
                out result);
        }

        private static byte[] DecodeBase64(string value)
        {
            string base64 = (value ?? string.Empty).Trim();
            int comma = base64.IndexOf(',');
            if (base64.StartsWith("data:", StringComparison.OrdinalIgnoreCase) && comma >= 0)
            {
                base64 = base64.Substring(comma + 1);
            }

            return Convert.FromBase64String(base64);
        }

        private static string EscapeFilter(string value)
        {
            return (value ?? string.Empty).Replace("'", "''");
        }

        private static string BuildSummary(ValidationResult result, bool valid)
        {
            string status = valid ? "VALID" : "INVALID";
            return string.Format(
                CultureInfo.InvariantCulture,
                "CSV {0}. Rows={1}; Valid={2}; Errors={3}; Transactions={4}; Period={5}..{6}; Total={7}",
                status,
                result.RowCount,
                result.ValidCount,
                result.Errors.Count,
                result.TransactionKeys.Count,
                result.PeriodStart.HasValue
                    ? result.PeriodStart.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                    : string.Empty,
                result.PeriodEnd.HasValue
                    ? result.PeriodEnd.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                    : string.Empty,
                result.TotalAmount);
        }

        private static string JoinErrors(List<string> errors, int maximum)
        {
            if (errors == null || errors.Count == 0)
            {
                return null;
            }

            int count = Math.Min(errors.Count, maximum);
            string[] selected = new string[count];
            for (int i = 0; i < count; i++)
            {
                selected[i] = errors[i];
            }

            string text = string.Join(" | ", selected);
            if (errors.Count > maximum)
            {
                text += " | ... " + (errors.Count - maximum).ToString(CultureInfo.InvariantCulture) +
                        " error lain";
            }

            return text;
        }

        private sealed class ValidationResult
        {
            public int RowCount;
            public int ValidCount;
            public DateTime? PeriodStart;
            public DateTime? PeriodEnd;
            public decimal TotalAmount;
            public readonly Dictionary<string, bool> TransactionKeys =
                new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
            public readonly List<string> Errors = new List<string>();
        }
    }
}
