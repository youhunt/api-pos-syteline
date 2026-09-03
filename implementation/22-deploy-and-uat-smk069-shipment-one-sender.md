# 22 — Deploy + UAT SMK069 Shipment One-Sender

> Date: 3 September 2026  
> Prerequisite: tenant metadata evidence in
> `tests/evidence/2026-09-03-smk069-shipment-runtime-metadata-and-dn22.md`.

## 1. Goal

Deploy and test the server-side method:

```text
SMK069SendOneShipment
```

without making the Shipment form the production sender.

Runtime flow:

```text
Prepare
-> HTTP POST
-> Complete
```

The method must be configured **non-transactional** because an external HTTP
request occurs between Prepare and Complete.

## 2. Service IDO shell

If `ue_SMK069ShipmentTransport` does not already exist, create a service IDO
shell using the Shipment outbound log as its technical base.

Suggested metadata:

```text
IDO Project        : existing SMK069 customization project
IDO Name           : ue_SMK069ShipmentTransport
Primary Base Table : ue_SMK069_shipment_api_log_mst
Table Alias        : svc
Primary Key        : RowPointer
Architectural Role : method/service IDO
```

Keep the generated bound properties for the first deployment. This IDO is not a
public direct-CRUD interface; the collection is only a technical base for
extension methods.

After save/check-in:

```text
Discard IDO Cache
start a fresh web-client session if metadata is still stale
```

## 3. Build From Source assembly

Open:

```text
IDO Extension Class Assemblies
```

Create:

```text
Assembly Name : ue_SMK069ShipmentExtensions
Assembly Type : Build From Source
Language      : C#
```

Add source:

```text
File Name:
SMK069ShipmentSenderExtension.cs

Repository source:
extension-classes/SMK069ShipmentSenderExtension.cs
```

Build the assembly and resolve all compiler errors before continuing.

The source uses standard framework/.NET namespaces including:

```text
System
System.Data
System.Net
System.IO
System.Text
Mongoose.IDO
Mongoose.IDO.DataAccess
```

Use the tenant's normal Mongoose IDO references. Add a framework reference only
if Build From Source explicitly reports a missing namespace/assembly.


### Tenant build correction — direct System.Data path retired

The first implementation used `ApplicationDB.Connection` and therefore needed
`System.Data.dll`. The tenant Build From Source compiler did not receive that
framework reference reliably.

That path is now **retired**.

Current source no longer imports:

```text
System.Data
Mongoose.IDO.DataAccess
```

and no longer uses:

```text
ApplicationDB
IDbCommand
IDbDataParameter
DbType
ParameterDirection
```

Instead it uses the Mongoose-native call path:

```text
Context.Commands.Invoke
```

to invoke two IDO Stored Procedure methods. Therefore **do not add
System.Data.dll** for the current source.


## 4. Link assembly to the IDO

Open `IDOs`, check out:

```text
ue_SMK069ShipmentTransport
```

Set:

```text
IDO Assembly Name   : ue_SMK069ShipmentExtensions
Ext Class Namespace : SMK069Shipment
Ext Class Name      : SMK069ShipmentTransportExtension
```

Save and check in.

## 5. Add the two Stored Procedure methods first

On IDO:

```text
ue_SMK069ShipmentTransport
```

add these two methods as **Stored Procedure** methods. They expose the already
stable SQL procedures to the extension class; they do not duplicate their
logic.

### Method A — SMK069PrepareShipmentSendSp

```text
Method Name      : SMK069PrepareShipmentSendSp
Method Type      : Stored Procedure
Stored Procedure : SMK069PrepareShipmentSendSp
```

Parameter order must match tenant metadata exactly:

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | DN_No | Input | Int64 |
| 2 | EndpointUrl | Input | String |
| 3 | LogRowPointer | Output | Guid |
| 4 | PayloadJson | Output | String |
| 5 | Success | Output | Int32 |
| 6 | Infobar | Output | String |

### Method B — SMK069CompleteShipmentSendSp

```text
Method Name      : SMK069CompleteShipmentSendSp
Method Type      : Stored Procedure
Stored Procedure : SMK069CompleteShipmentSendSp
```

Parameter order:

| Seq | Parameter | Direction | Type |
|---:|---|---|---|
| 1 | LogRowPointer | Input | Guid |
| 2 | HttpCode | Input | Int32 |
| 3 | ResponseJson | Input | String |
| 4 | IsSuccess | Input | Int32 |
| 5 | Success | Output | Int32 |
| 6 | Infobar | Output | String |

These methods execute under the same Mongoose caller/session context, so the
existing stored procedures continue to resolve Site from `CONTEXT_INFO()` and
call `SetSiteSp`.

Save/check in the IDO and discard IDO cache before testing the extension
orchestration.

## 6. Add transport method metadata

Add extension-class standard method:

```text
Method Name   : SMK069PostShipmentPayload
Transactional : NOT checked
```

Parameters in exact order:

| Seq | Name | Direction | Type |
|---:|---|---|---|
| 1 | EndpointUrl | Input | String |
| 2 | RequestJson | Input | String |
| 3 | AuthHeaderName | Input | String |
| 4 | AuthHeaderValue | Input | String |
| 5 | SuccessMode | Input | String |
| 6 | SuccessMarker | Input | String |
| 7 | TimeoutSeconds | Input | Int32 |
| 8 | HttpCode | Output | Int32 |
| 9 | ResponseJson | Output | String |
| 10 | TransportSuccess | Output | Int32 |
| 11 | BusinessSuccess | Output | Int32 |
| 12 | ErrorMessage | Output | String |
| 13 | Infobar | Output | String |

## 7. Add one-Shipment method metadata

Add extension-class standard method:

```text
Method Name   : SMK069SendOneShipment
Transactional : NOT checked
```

Parameters in exact order:

| Seq | Name | Direction | Type |
|---:|---|---|---|
| 1 | DN_No | Input | Int64 |
| 2 | EndpointUrl | Input | String |
| 3 | AuthHeaderName | Input | String |
| 4 | AuthHeaderValue | Input | String |
| 5 | SuccessMode | Input | String |
| 6 | SuccessMarker | Input | String |
| 7 | TimeoutSeconds | Input | Int32 |
| 8 | LogRowPointer | Output | String |
| 9 | PayloadJson | Output | String |
| 10 | HttpCode | Output | Int32 |
| 11 | ResponseJson | Output | String |
| 12 | TransportSuccess | Output | Int32 |
| 13 | BusinessSuccess | Output | Int32 |
| 14 | ErrorMessage | Output | String |
| 15 | Success | Output | Int32 |
| 16 | Infobar | Output | String |

After adding both methods:

```text
Save
Check In
Discard IDO Cache
new web-client session if required
```

## 8. Pre-UAT check for DN22

Use Query Execution:

```sql
SELECT
    SiteRef,
    ShipmentId,
    EndpointUrl,
    RequestDate,
    ResponseDate,
    ResponseHttpCode,
    ProcessStatus,
    RetryCount,
    RowPointer
FROM dbo.ue_SMK069_shipment_api_log_mst
WHERE SiteRef =
      RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ShipmentId = 22
ORDER BY RequestDate DESC;
```

This is important because DN22 was already used for manual Prepare UAT. An
existing `N` row is not automatically a problem; Prepare is designed to reuse
the existing NEW log for the same Site + Shipment.

Do not delete audit rows merely to make the test look clean.

## 9. Negative one-Shipment UAT — safe first test

Use the reserved `.invalid` domain so the request cannot resolve to a real
Internet service:

```text
DN_No           = 22
EndpointUrl     = https://smk069-pos.invalid/shipment
AuthHeaderName  = <blank>
AuthHeaderValue = <blank>
SuccessMode     = UNCONFIRMED
SuccessMarker   = <blank>
TimeoutSeconds  = 10
```

Expected IDO outputs:

```text
LogRowPointer   = populated
PayloadJson     = populated with DN22 and four lot rows
HttpCode        = 0 normally for DNS/connection failure
TransportSuccess= 0
BusinessSuccess = 0
Success         = 0
ReturnValue     = 0 if Complete successfully records the failed attempt
```

Expected database state:

```text
outbound log ProcessStatus = E
RetryCount                 = previous + 1 according to Complete logic
shipment api_post          = 0
shipment api_post_date     = unchanged/null
```

The important distinction:

```text
ReturnValue = 0
```

means the orchestration handled the attempt and persisted its result. It does
not mean the POS accepted the Shipment. Business result is the output
`Success`.

## 10. Verify the failed attempt

Query Execution:

```sql
SELECT
    SiteRef,
    ShipmentId,
    EndpointUrl,
    RequestDate,
    ResponseDate,
    ResponseHttpCode,
    ProcessStatus,
    RetryCount,
    ResponseJson,
    ErrorMessage,
    RowPointer
FROM dbo.ue_SMK069_shipment_api_log_mst
WHERE SiteRef =
      RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ShipmentId = 22
ORDER BY RequestDate DESC;
```

Then:

```sql
SELECT
    site_ref,
    DN_No,
    Api_post,
    Api_post_date
FROM dbo.SMK069_ShipmentAPI_mst
WHERE site_ref =
      RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND CONVERT(NVARCHAR(50), DN_No) = '22'
GROUP BY
    site_ref,
    DN_No,
    Api_post,
    Api_post_date;
```

Expected:

```text
Api_post = 0
```

## 11. Do not run positive UAT yet unless POS contract is available

Before a test that may set DN22 `api_post=1`, obtain:

```text
UAT Shipment endpoint
authentication/header
sample accepted response
sample business-error response
duplicate DN behavior
confirmation whether HTTP 2xx alone means success
```

Recommended starting success mode:

```text
MARKER
```

when a stable response marker is available.

Keep:

```text
UNCONFIRMED
```

while the response contract remains open.

## 12. Stop point

Do not enable the hourly TaskMan schedule yet.

Proceed to the pending-batch sender and scheduler only after:

```text
[ ] assembly builds
[ ] service IDO loads
[ ] both extension methods are visible
[ ] negative DN22 UAT records log E
[ ] DN22 remains api_post=0 after negative UAT
[ ] POS UAT endpoint/auth/response contract is confirmed
[ ] one positive Shipment UAT succeeds
```


### Tenant correction — namespace and class must not be reversed

The tenant Method Wizard returned:

```text
Type 'SMK069ShipmentTransportExtension.SMK069Shipment' not found
in assembly 'ue_SMK069ShipmentExtensions'.
```

This means the IDO Extension Class identity was entered in reverse.

Correct IDO values:

```text
IDO Assembly Name   : ue_SMK069ShipmentExtensions
Ext Class Namespace : SMK069Shipment
Ext Class Name      : SMK069ShipmentTransportExtension
```

The full CLR type must therefore resolve as:

```text
SMK069Shipment.SMK069ShipmentTransportExtension
```

After correcting the IDO:

```text
Save
Check In
Discard IDO Cache
reopen Method Wizard
```

The confirmed Stored Procedure method
`SMK069PrepareShipmentSendSp` already showed the expected parameter order:

```text
DN_No
EndpointUrl
LogRowPointer
PayloadJson
Success
Infobar
```
