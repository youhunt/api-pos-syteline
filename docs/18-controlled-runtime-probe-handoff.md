# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Safety Boundary

```text
Environment                        : DEV
Disposable Customer Order testing : ALLOWED
```

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

## Completed Probe Results

Probe 1 submitted raw `{` and confirmed that `CoAndLineInfoJson` must be Base64-encoded.

Probe 2 submitted:

```text
Base64          : ew==
Decoded content : {
```

The tenant returned a `JObject` parser failure. This confirms:

```text
CoAndLineInfoJson
→ Base64-encoded content
→ decoded content parsed as JSON object / JObject
→ schema validation and Customer Order processing
```

`MessageCode = 0` does not establish business success. Read and parse `CoResult`. The failure branch is a string containing a JSON array with `Status = Fail` and the exact error key `ErrrorMessage`.

## Completed No-Order Verifications

After each of the first two probes, the same read-only recent-order query was executed against `dbo.co_mst`.

```text
Probe 1 check : zero rows
Probe 2 check : zero rows
SQL errors    : none
```

No unexpected Customer Order was found in either checked 30-minute window.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
```

## Current Unknowns

```text
- exact JSON property names and nesting
- required header and line fields
- date and numeric formats
- co_num generation behavior
- success CoResult shape
- atomicity
```

## Next Step Only

Submit the empty JSON object `{}` as Base64:

```text
Raw decoded content : {}
Base64              : e30=
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
parms = e30=,
```

The trailing comma supplies the blank initial value for `CoResult`.

Expected URL fragment:

```text
?parms=e30%3D,
```

Capture the complete HTTP status and JSON response. Do not add any JSON property or retry with another payload during the same step.

## Status

```text
Raw malformed probe               : COMPLETED
Base64 requirement                : CONFIRMED
First no-order check              : COMPLETED — ZERO ROWS
Base64 malformed JSON probe       : COMPLETED
JSON object / JObject requirement : CONFIRMED
Second no-order check             : COMPLETED — ZERO ROWS
Empty-object probe                : AUTHORIZED — NOT YET RUN
Valid order probe                 : NOT READY
Process/Reprocess                 : NOT STARTED
Customer Order creation           : NOT STARTED
Controlled receive API            : NOT STARTED
```

## Safety Boundary for Next Probe

```text
- Use exactly e30= as parameter 1.
- Retain the trailing comma for blank parameter 2.
- Do not add customer, item, order, site, date, quantity, or price data.
- Do not guess schema property names.
- Do not submit another payload in the same step.
- Run another separate read-only Customer Order check after the response.
```