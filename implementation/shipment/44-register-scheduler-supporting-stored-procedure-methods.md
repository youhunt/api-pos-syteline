# Register Shipment Scheduler Supporting Stored-Procedure Methods

Date: 2026-09-08

## Why the Method Name dropdown only shows C# methods

On `ue_SMK069ShipmentTransport`, when the IDO Method Wizard is set to:

```text
Method Type = Extension Class - Standard Method
```

the Method Name dropdown only enumerates public `[IDOMethod]` members from the compiled extension class. The tenant correctly shows methods such as:

```text
SMK069SendPendingShipments
SMK069SendOneShipmentKacs
SMK069SendOneShipment
SMK069PostShipmentPayload
SMK069RunDueShipmentSchedule
```

Stored procedures do NOT appear in that dropdown. This is expected and is not evidence that the scheduler SQL procedures are missing from the database.

## The runner still requires five IDO stored-procedure methods

`SMK069RunDueShipmentSchedule` and `SMK069SendPendingShipments` invoke these through `Context.Commands.Invoke`:

```text
SMK069GetShipmentConfigSp
SMK069GetPendingShipmentsSp
SMK069RecordShipmentAttemptSp
SMK069ClaimDueShipmentScheduleSp
SMK069CompleteShipmentScheduleSp
```

These must be registered on IDO:

```text
ue_SMK069ShipmentTransport
```

as stored-procedure methods, not extension-class methods.

## How to register each stored procedure

Create a new IDO method record and use:

```text
Method Type      : Stored Procedure
Stored Procedure : <matching dbo procedure>
Method Name      : same name as procedure
```

Use the method wizard / parameter synchronization so the parameter order follows the stored procedure definition.

### 1. SMK069GetShipmentConfigSp

```text
1 IsEnabled       OUT Int32
2 LoginUrl        OUT String
3 EndpointUrl     OUT String
4 SuccessMode     OUT String
5 TimeoutSeconds  OUT Int32
6 MaxBatchSize    OUT Int32
7 Infobar         OUT String
```

### 2. SMK069GetPendingShipmentsSp

```text
1 MaxRows          IN  Int32
2 PendingList      OUT String
3 PendingCount     OUT Int32
4 DueLaterCount    OUT Int32
5 ExhaustedCount   OUT Int32
6 Infobar          OUT String
```

### 3. SMK069RecordShipmentAttemptSp

```text
1 DN_No            IN  String
2 IsSuccess        IN  Int32
3 HttpCode         IN  Int32
4 ErrorMessage     IN  String
5 AttemptCount     OUT Int32
6 NextAttemptDate  OUT DateTime
7 Exhausted        OUT Int32
8 Infobar          OUT String
```

Important: `DN_No` must remain String because shipment IDs are prefixed values such as `P96327`.

### 4. SMK069ClaimDueShipmentScheduleSp

```text
1 ScheduleCode  OUT String
2 MaxShipments  OUT Int32
3 HasWork       OUT Int32
4 Infobar       OUT String
```

### 5. SMK069CompleteShipmentScheduleSp

```text
1 ScheduleCode  IN  String
2 ResultCode    IN  Int32
3 Candidates    IN  Int32
4 Succeeded     IN  Int32
5 Failed        IN  Int32
6 Exhausted     IN  Int32
7 Message       IN  String
8 Success       OUT Int32
9 Infobar       OUT String
```

## Correct distinction

```text
C# runner
  Method Type = Extension Class - Standard Method
  Method       = SMK069RunDueShipmentSchedule

SQL helpers
  Method Type = Stored Procedure
  Methods     = the five procedures listed above
```

Do not search for the SQL procedure names while Method Type is set to `Extension Class - Standard Method`; they will never appear in that dropdown.

## UAT gate

Before creating/enabling TaskMan, confirm all of these IDO methods exist on `ue_SMK069ShipmentTransport`:

```text
[Extension]
SMK069RunDueShipmentSchedule
SMK069SendPendingShipments

[Stored Procedure]
SMK069GetShipmentConfigSp
SMK069GetPendingShipmentsSp
SMK069RecordShipmentAttemptSp
SMK069ClaimDueShipmentScheduleSp
SMK069CompleteShipmentScheduleSp
```

Only after this list is complete should the one-DN UAT (`MaxShipments = 1`) be run.
