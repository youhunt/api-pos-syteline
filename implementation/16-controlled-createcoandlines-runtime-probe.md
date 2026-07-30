# Implementation 16 — Controlled CreateCoAndLines Runtime Probe

## Status

```text
Environment                        : DEV
Disposable testing                 : ALLOWED
Raw malformed probe                : COMPLETED
Base64 requirement                 : CONFIRMED
First no-order check               : COMPLETED — ZERO ROWS
Base64 malformed JSON probe        : COMPLETED
Decoded payload type               : JSON object / JObject
Second no-order check              : COMPLETED — ZERO ROWS
Empty-object probe                 : AUTHORIZED — NOT YET EXECUTED
Valid Customer Order probe         : NOT READY
Exact JSON schema                  : NOT YET CONFIRMED
Customer Order creation            : NOT STARTED
```

## Confirmed Method

```text
IDO             : SLCos
Method          : CreateCoAndLines
Method Type     : Extension Class - Standard Method
Implementation  : Customer.SLCos
Assembly        : Customer — Binary Only
Transactional   : false
```

Parameters:

```text
CoAndLineInfoJson : input-only
CoResult          : input/output + message
```

## Probe 1 Result

Raw `{` failed before JSON parsing because the method expects Base64 content.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
```

## Probe 2 Result

Submitted:

```text
CoAndLineInfoJson : ew==
Decoded content   : {
CoResult initial  : blank
```

Tenant response:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "ew==",
    "[{\"ErrrorMessage\":\"Error reading JObject from JsonReader. Path '', line 1, position 1.\",\"Status\":\"Fail\",\"Message\":\"Error occurred during customer order/line creation\"}]"
  ],
  "ReturnValue": null
}
```

Confirmed contract:

```text
CoAndLineInfoJson
1. Base64 decode
2. parse decoded content as a JSON object / JObject
3. validate Customer Order schema and process
```

`MessageCode = 0` does not mean business success. The business result remains in `CoResult`, which is a string containing a JSON array. The exact failure key is `ErrrorMessage`.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
```

## Second No-Order Verification — Completed

The standard recent-order query was executed after the `ew==` probe.

Tenant result:

```text
SQL error                         : none
Rows returned                    : 0
Unexpected recent Customer Order : not found
```

Therefore the Base64 malformed JSON probe did not create or update a Customer Order within the checked 30-minute window.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
```

## Remaining Unknowns

```text
- exact JSON property names and nesting
- required header fields
- required line fields
- date and numeric formats
- co_num generation behavior
- success CoResult shape
- atomicity of header and line creation
```

## Current Small Step — Empty JSON Object Probe

Submit only an empty JSON object encoded as Base64:

```text
Raw decoded content : {}
Base64 value        : e30=
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
Value : e30=,
```

Expected encoded URL fragment:

```text
?parms=e30%3D,
```

Purpose:

```text
- pass Base64 decoding;
- pass JSON-object parsing;
- reach schema validation;
- capture the first missing-property or validation error without using customer, item, or valid order values.
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
- Use exactly e30= as parameter 1.
- Keep parameter 2 blank by retaining the trailing comma.
- Do not add any JSON property.
- Do not use customer, item, site, order number, date, quantity, or price values.
- Do not retry with another payload in the same step.
- Do not create Process/Reprocess logic.
- After the response, perform another separate read-only Customer Order verification before advancing.
```