# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Confirmed Safety Boundary

```text
Environment                        : DEV
Disposable Customer Order testing : ALLOWED
```

The environment gate for a controlled runtime probe is passed.

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

## Current Unknowns

```text
- exact CoAndLineInfoJson schema
- required and optional header fields
- required and optional line fields
- co_num generation behavior
- success CoResult shape
- failure CoResult shape
- atomicity of header and line creation
```

## Next Step Only

Run one deliberately malformed JSON contract probe:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/method/SLCos/CreateCoAndLines?parms=%7B,
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Postman Params equivalent:

```text
parms = {,
```

The first parameter is the malformed JSON value `{`; the trailing comma supplies the blank initial value for `CoResult`.

Capture the complete HTTP status and JSON response. Do not replace the malformed payload with guessed valid JSON during this step.

## Status

```text
Environment gate           : PASSED
Malformed runtime probe    : READY — NOT YET EXECUTED
Valid order probe          : NOT READY
Process/Reprocess           : NOT STARTED
Customer Order creation     : NOT STARTED
Controlled receive API      : NOT STARTED
```

## Evidence

```text
tests/evidence/2026-07-30-dev-runtime-test-boundary.md
implementation/16-controlled-createcoandlines-runtime-probe.md
```
