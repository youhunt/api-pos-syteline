# Implementation 16 — Controlled CreateCoAndLines Runtime Probe

## Status

```text
Environment                         : DEV
Disposable Customer Order testing  : ALLOWED
Safety gate                         : PASSED
Raw-JSON malformed probe            : COMPLETED
Base64 input requirement            : CONFIRMED
No-order read-only verification     : COMPLETED — ZERO ROWS
Base64 malformed-content probe      : AUTHORIZED — NOT YET EXECUTED
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

| Sequence | Parameter | Direction |
| ---: | --- | --- |
| 1 | `CoAndLineInfoJson` | input-only |
| 2 | `CoResult` | input/output + message |

## First Runtime Probe — Completed

Submitted values:

```text
CoAndLineInfoJson = {
CoResult          = blank
```

Request:

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

```text
CoAndLineInfoJson = Base64-encoded content
```

`MessageCode = 0` confirms only that the Mongoose method invocation reached the method layer. It does not establish Customer Order creation success.

The business result is carried in `CoResult`, which was returned as a string containing a JSON array:

```json
[
  {
    "ErrrorMessage": "...",
    "Status": "Fail",
    "Message": "Error occurred during customer order/line creation"
  }
]
```

The exact tenant key is `ErrrorMessage` with three consecutive `r` characters. Do not silently normalize this key before additional result branches are verified.

## No-Order Verification — Completed

The following read-only query was executed after the first probe:

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

Tenant result:

```text
SQL error                         : none
Rows returned                    : 0
Unexpected recent Customer Order : not found
```

Therefore the deliberately malformed raw-input probe did not create a Customer Order within the 30-minute verification window.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
```

## Current Small Step — Base64 Malformed JSON Probe

The next probe is now authorized because:

```text
- environment is DEV;
- disposable testing is allowed;
- the first malformed probe failed at Base64 decoding;
- the post-probe Customer Order check returned zero rows.
```

Use only the Base64 representation of malformed JSON `{`:

```text
Raw decoded content : {
Base64 value        : ew==
CoResult initial    : blank
```

Postman request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/method/SLCos/CreateCoAndLines
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Postman Params:

```text
Key   : parms
Value : ew==,
```

Expected encoded URL fragment:

```text
?parms=ew%3D%3D,
```

Purpose:

```text
- pass the Base64 decoder;
- reach the decoded-content JSON parser or validation layer;
- capture the next tenant error without using real order data.
```

Capture the complete response:

```text
HTTP status
Message
MessageCode
ReturnValue
Parameters
```

## Safety Boundary

```text
- Use exactly ew== as parameter 1.
- Keep parameter 2 blank by retaining the trailing comma.
- Do not use valid Customer Order values.
- Do not guess JSON property names.
- Do not retry with another payload in the same step.
- Do not create Process/Reprocess logic.
- Do not import CSV or create the controlled receive API method.
- After the response, perform another separate read-only Customer Order check before advancing.
```
