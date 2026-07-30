# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Confirmed Safety Boundary

```text
Environment                        : DEV
Disposable Customer Order testing : ALLOWED
```

The environment gate for controlled runtime probing is passed.

## Confirmed Method

```text
IDO             : SL.SLCos
Method          : CreateCoAndLines
Method Type     : Extension Class - Standard Method
Implementation  : Customer.SLCos
Assembly        : Customer — Binary Only
Transactional   : false
```

Parameters:

```text
CoAndLineInfoJson : input-only
CoResult          : input/output + message parameter
```

## Completed First Runtime Probe

Submitted values:

```text
CoAndLineInfoJson : {
CoResult          : blank
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

Confirmed discovery:

```text
CoAndLineInfoJson must contain Base64-encoded content.
```

`MessageCode = 0` does not establish business success. Read the returned `CoResult` string and parse its JSON-array content.

Observed failure keys:

```text
Status        : Fail
Message       : Error occurred during customer order/line creation
Error key     : ErrrorMessage
```

The exact key `ErrrorMessage` contains three consecutive `r` characters.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
```

## Completed No-Order Verification

A read-only query checked `dbo.co_mst` for orders created or changed in the previous 30 minutes.

Result:

```text
SQL error                         : none
Rows returned                    : 0
Unexpected recent Customer Order : not found
```

The raw malformed probe therefore did not create a Customer Order within the checked window.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
```

## Current Unknowns

```text
- decoded JSON property names and nesting
- required and optional header fields
- required and optional line fields
- co_num generation behavior
- success CoResult shape
- deeper JSON parsing or validation errors
- atomicity of header and line creation
```

## Next Step Only

Send Base64 for the deliberately malformed decoded content `{`:

```text
Raw content : {
Base64      : ew==
```

Postman request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/method/SLCos/CreateCoAndLines
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Postman Params:

```text
parms = ew==,
```

The trailing comma supplies the blank initial value for `CoResult`.

Expected URL fragment:

```text
?parms=ew%3D%3D,
```

Capture the complete HTTP status and JSON response. Do not submit another payload during the same step.

## Status

```text
Environment gate              : PASSED
Raw JSON malformed probe      : COMPLETED
Base64 requirement            : CONFIRMED
No-order read-only check      : COMPLETED — ZERO ROWS
Base64 malformed-content test : AUTHORIZED — NOT YET RUN
Valid order probe             : NOT READY
Process/Reprocess              : NOT STARTED
Customer Order creation        : NOT STARTED
Controlled receive API         : NOT STARTED
```

## Safety Boundary

```text
- Use exactly ew== as parameter 1.
- Keep the trailing comma for blank parameter 2.
- Do not use real Customer Order values.
- Do not guess schema property names.
- Do not retry with another payload in the same step.
- Re-run a separate read-only Customer Order check after the response.
```
