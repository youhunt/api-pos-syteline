# Implementation 16 — Controlled CreateCoAndLines Runtime Probe

## Status

```text
Environment                         : DEV
Disposable Customer Order testing  : ALLOWED
Safety gate                         : PASSED
Malformed-contract probe            : READY — NOT YET EXECUTED
Valid Customer Order probe          : NOT READY
CreateCoAndLines JSON schema         : NOT YET CONFIRMED
Customer Order creation              : NOT STARTED
```

## Confirmed Method Contract

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Implementation: Customer.SLCos in binary-only assembly Customer
Transactional : false
```

Parameters:

| Sequence | Parameter | Direction |
| ---: | --- | --- |
| 1 | `CoAndLineInfoJson` | input-only |
| 2 | `CoResult` | input/output + message |

## Purpose of First Runtime Probe

The first invocation is not a Customer Order creation test. It is a contract-error probe designed to confirm how the binary extension reports malformed JSON.

Use deliberately malformed JSON:

```text
CoAndLineInfoJson = {
CoResult          = blank
```

This malformed value is selected to force a JSON parsing or validation failure before a valid Customer Order payload can be processed.

## Request

Use REST API v1 InvokeMethod:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/method/SLCos/CreateCoAndLines?parms=%7B,
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Equivalent Postman Params value:

```text
Key   : parms
Value : {,
```

Do not add spaces after the comma.

## Expected Evidence

Capture the complete response, including:

```text
HTTP status
Message
MessageCode
ReturnValue
Parameters
```

A failure response is expected. Do not interpret HTTP 200 alone as method success; inspect `MessageCode`, `ReturnValue`, and returned `CoResult`.

## Safety Boundary

```text
- Do not replace `{` with valid JSON yet.
- Do not use real Customer Order values.
- Do not retry with guessed property names.
- Do not create Process/Reprocess logic.
- Do not import CSV or create the receive API method.
- After the response is reviewed, perform a separate read-only Customer Order verification before advancing.
```

Evidence for environment authorization:

```text
tests/evidence/2026-07-30-dev-runtime-test-boundary.md
```
