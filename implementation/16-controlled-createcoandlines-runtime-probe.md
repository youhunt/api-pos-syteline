# Implementation 16 — Controlled CreateCoAndLines Runtime Probe

## Status

```text
Environment                         : DEV
Disposable Customer Order testing  : ALLOWED
Safety gate                         : PASSED
Raw-JSON malformed probe            : COMPLETED
Base64 input requirement            : CONFIRMED
No-order read-only verification     : PENDING
Base64 malformed-content probe      : NOT YET AUTHORIZED
Valid Customer Order probe          : NOT READY
Decoded JSON schema                 : NOT YET CONFIRMED
Customer Order creation             : NOT STARTED
```

## Confirmed Method Contract

```text
IDO Name       : SLCos
Method Name    : CreateCoAndLines
Method Type    : Extension Class - Standard Method
Implementation : Customer.SLCos in binary-only assembly Customer
Transactional  : false
```

Parameters:

| Sequence | Parameter | Direction |
| ---: | --- | --- |
| 1 | `CoAndLineInfoJson` | input-only |
| 2 | `CoResult` | input/output + message |

## First Runtime Probe — Completed

The first invocation deliberately supplied raw malformed JSON rather than a real order payload:

```text
CoAndLineInfoJson = {
CoResult          = blank
```

Request pattern:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/method/SLCos/CreateCoAndLines?parms=%7B,
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Tenant response:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "{",
    "[{\"ErrrorMessage\":\"The input is not a valid Base-64 string as it contains a non-base 64 character, more than two padding characters, or an illegal character among the padding characters. \",\"Status\":\"Fail\",\"Message\":\"Error occurred during customer order/line creation\"}]"
  ],
  "ReturnValue": null
}
```

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
```

## Confirmed Discovery

The Mongoose method invocation itself completed at the transport/framework layer:

```text
Message     : null
MessageCode : 0
ReturnValue : null
```

But the business result returned through `CoResult` is:

```text
Status  : Fail
Message : Error occurred during customer order/line creation
Error   : input is not valid Base64
```

Therefore `MessageCode = 0` must not be interpreted as Customer Order creation success.

The input contract is now refined to:

```text
CoAndLineInfoJson = Base64-encoded content
```

The decoded content is still expected to be JSON based on the parameter name, but its exact schema remains unknown.

## Confirmed CoResult Shape — Failure Branch Only

`CoResult` was returned as a string containing a JSON array:

```json
[
  {
    "ErrrorMessage": "...",
    "Status": "Fail",
    "Message": "Error occurred during customer order/line creation"
  }
]
```

Important tenant observation:

```text
ErrrorMessage
```

contains three consecutive `r` characters. Do not normalize or replace this key in integration code until additional result branches are verified.

## Safety Interpretation

The failure occurred during Base64 decoding, which strongly indicates that valid decoded order content was never processed. However, no-order creation is not marked verified until a separate read-only Customer Order check is completed.

## Current Small Step — Read-Only Customer Order Verification

Before sending Base64 input, perform a read-only check for Customer Orders created around the probe time.

Preferred SQL read-only verification in the DEV application database:

```sql
SELECT TOP (20)
       co_num,
       cust_num,
       order_date,
       CreateDate,
       CreatedBy,
       RecordDate,
       UpdatedBy
FROM dbo.co_mst
WHERE RecordDate >= DATEADD(MINUTE, -30, GETDATE())
   OR CreateDate >= DATEADD(MINUTE, -30, GETDATE())
ORDER BY COALESCE(RecordDate, CreateDate) DESC;
```

If the tenant schema reports that `CreateDate` or `CreatedBy` is unavailable, stop and return the exact SQL error; do not guess replacement columns in the same step.

Send the result rows, including an empty result. Do not invoke `CreateCoAndLines` again yet.

## Next Probe — Not Yet Run

Only after read-only verification confirms no unexpected order creation, the next controlled probe may use Base64 for the malformed decoded content `{`:

```text
Raw content : {
Base64      : ew==
```

That future probe is intended to move from the Base64 decoder to the JSON parser. It is not authorized as part of the current step.

## Safety Boundary

```text
- Do not send ew== yet.
- Do not use a valid Customer Order JSON payload.
- Do not guess JSON property names.
- Do not create Process/Reprocess logic.
- Do not import CSV or create the receive API method.
- Do not mark Customer Order creation as absent until read-only evidence is returned.
```