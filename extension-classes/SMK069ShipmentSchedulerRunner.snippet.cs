/*
 * SMK069 Shipment Scheduler runner snippet
 * Date: 2026-09-08
 *
 * IMPORTANT:
 * - Paste these members INSIDE the existing SMK069ShipmentTransportExtension class.
 * - Do NOT create a second IDOExtensionClass for ue_SMK069ShipmentTransport.
 * - Requires Patch 08 Rev.2 and Patch 09.
 * - Requires the existing SMK069SendPendingShipments method from revision 3.
 * - Register SMK069RunDueShipmentSchedule as NON-TRANSACTIONAL.
 */

[IDOMethod(MethodFlags.None, "Infobar")]
public int SMK069RunDueShipmentSchedule(
    string Username,
    string Password,
    ref string ScheduleCode,
    ref int Candidates,
    ref int Succeeded,
    ref int Failed,
    ref int Exhausted,
    ref string Infobar)
{
    ScheduleCode = null;
    Candidates = 0;
    Succeeded = 0;
    Failed = 0;
    Exhausted = 0;
    Infobar = null;

    if (string.IsNullOrWhiteSpace(Username) ||
        string.IsNullOrWhiteSpace(Password))
    {
        Infobar = "Username dan Password POS wajib diisi pada definisi TaskMan.";
        return 16;
    }

    int maxShipments = 0;
    int hasWork = 0;
    string claimInfobar = null;

    try
    {
        ClaimDueShipmentSchedule(
            out ScheduleCode,
            out maxShipments,
            out hasWork,
            out claimInfobar);
    }
    catch (Exception ex)
    {
        Infobar = "Claim Shipment schedule gagal: " + ex.Message;
        return 16;
    }

    if (hasWork != 1 || string.IsNullOrWhiteSpace(ScheduleCode))
    {
        Infobar = string.IsNullOrWhiteSpace(claimInfobar)
            ? "Tidak ada Shipment schedule yang jatuh tempo."
            : claimInfobar;
        return 0;
    }

    int sendReturn = 16;
    string failedList = null;
    string sendInfobar = null;

    try
    {
        sendReturn = SMK069SendPendingShipments(
            Username,
            Password,
            maxShipments,
            ref Candidates,
            ref Succeeded,
            ref Failed,
            ref Exhausted,
            ref failedList,
            ref sendInfobar);
    }
    catch (Exception ex)
    {
        sendReturn = 16;
        sendInfobar = "Shipment batch exception: " + ex.Message;
    }

    string resultMessage = sendInfobar;
    if (!string.IsNullOrWhiteSpace(failedList))
    {
        resultMessage = AppendMessage(resultMessage, "Failed: " + failedList);
    }

    int completeSuccess = 0;
    string completeInfobar = null;

    try
    {
        CompleteShipmentSchedule(
            ScheduleCode,
            sendReturn,
            Candidates,
            Succeeded,
            Failed,
            Exhausted,
            resultMessage,
            out completeSuccess,
            out completeInfobar);
    }
    catch (Exception ex)
    {
        Infobar =
            "Schedule " + ScheduleCode +
            " sudah diklaim tetapi penyelesaian schedule gagal: " + ex.Message +
            ". Lease akan kedaluwarsa otomatis.";
        return 16;
    }

    if (completeSuccess != 1)
    {
        Infobar = string.IsNullOrWhiteSpace(completeInfobar)
            ? "Gagal menyelesaikan Shipment schedule."
            : completeInfobar;
        return 16;
    }

    Infobar =
        "Schedule " + ScheduleCode + ". " +
        (string.IsNullOrWhiteSpace(sendInfobar)
            ? string.Empty
            : sendInfobar + " ") +
        (string.IsNullOrWhiteSpace(completeInfobar)
            ? string.Empty
            : completeInfobar);

    return sendReturn;
}

private void ClaimDueShipmentSchedule(
    out string scheduleCode,
    out int maxShipments,
    out int hasWork,
    out string infobar)
{
    scheduleCode = null;
    maxShipments = 0;
    hasWork = 0;
    infobar = null;

    InvokeResponseData response = this.Context.Commands.Invoke(
        "ue_SMK069ShipmentTransport",
        "SMK069ClaimDueShipmentScheduleSp",
        IDONull.Value,
        IDONull.Value,
        IDONull.Value,
        IDONull.Value);

    if (response == null || response.Parameters.Count < 4)
    {
        throw new InvalidOperationException(
            "SMK069ClaimDueShipmentScheduleSp harus memiliki 4 parameter.");
    }

    infobar = response.Parameters[3].IsNull
        ? null
        : response.Parameters[3].Value;

    if (response.IsReturnValueStdError())
    {
        throw new InvalidOperationException(
            string.IsNullOrWhiteSpace(infobar)
                ? "SMK069ClaimDueShipmentScheduleSp gagal."
                : infobar);
    }

    scheduleCode = response.Parameters[0].IsNull
        ? null
        : response.Parameters[0].Value;

    if (!response.Parameters[1].IsNull)
    {
        maxShipments = response.Parameters[1].GetValue<int>();
    }

    if (!response.Parameters[2].IsNull)
    {
        hasWork = response.Parameters[2].GetValue<int>();
    }
}

private void CompleteShipmentSchedule(
    string scheduleCode,
    int resultCode,
    int candidates,
    int succeeded,
    int failed,
    int exhausted,
    string message,
    out int success,
    out string infobar)
{
    success = 0;
    infobar = null;

    InvokeResponseData response = this.Context.Commands.Invoke(
        "ue_SMK069ShipmentTransport",
        "SMK069CompleteShipmentScheduleSp",
        scheduleCode,
        resultCode,
        candidates,
        succeeded,
        failed,
        exhausted,
        string.IsNullOrWhiteSpace(message)
            ? IDONull.Value
            : (object)LimitBody(message, 1000),
        IDONull.Value,
        IDONull.Value);

    if (response == null || response.Parameters.Count < 9)
    {
        throw new InvalidOperationException(
            "SMK069CompleteShipmentScheduleSp harus memiliki 9 parameter.");
    }

    infobar = response.Parameters[8].IsNull
        ? null
        : response.Parameters[8].Value;

    if (response.IsReturnValueStdError())
    {
        throw new InvalidOperationException(
            string.IsNullOrWhiteSpace(infobar)
                ? "SMK069CompleteShipmentScheduleSp gagal."
                : infobar);
    }

    if (!response.Parameters[7].IsNull)
    {
        success = response.Parameters[7].GetValue<int>();
    }
}
