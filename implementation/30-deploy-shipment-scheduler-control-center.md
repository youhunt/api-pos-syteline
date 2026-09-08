# SMK069 Shipment Scheduler — TaskMan Runner Wiring

> Date: 2026-09-08  
> Depends on: Patch 08 revision 2 + Patch 09  
> Target extension class: the existing class bound to `ue_SMK069ShipmentTransport`

Patch 09 makes schedules editable from the Mongoose control-center form.
This runner is the small bridge that lets a fixed TaskMan heartbeat consume those
form-defined schedules without storing credentials in the database.

Do **not** create a second extension class for the same IDO. Paste the methods
below inside the existing `SMK069ShipmentTransportExtension` class (the class in
`SMK069ShipmentSenderExtension.rev3.cs`).

## IDO method

```csharp
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
        resultMessage = AppendMessage(
            resultMessage,
            "Failed: " + failedList);
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
```

## Private helper — claim

```csharp
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
```

## Private helper — complete

```csharp
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
```

## Register method

On `ue_SMK069ShipmentTransport`:

```text
Method Name   : SMK069RunDueShipmentSchedule
Method Type   : Extension Class - Standard Method
Transactional : NOT checked
```

Parameters:

| Seq | Name | Direction | Type |
|---:|---|---|---|
| 1 | Username | Input | String |
| 2 | Password | Input | String |
| 3 | ScheduleCode | Output | String |
| 4 | Candidates | Output | Int32 |
| 5 | Succeeded | Output | Int32 |
| 6 | Failed | Output | Int32 |
| 7 | Exhausted | Output | Int32 |
| 8 | Infobar | Output | String |

## TaskMan definition

TaskMan no longer owns the business interval. It only polls for due schedules.

Suggested first UAT setup:

```text
Heartbeat           : every 5 minutes
Method              : SMK069RunDueShipmentSchedule
Username / Password : TaskMan parameters only
```

A 60-minute schedule in the form will therefore run at the first heartbeat after
its `NextRunDate` becomes due.

Do not run this method interactively with production credentials; Mongoose can
echo method inputs in its response.
