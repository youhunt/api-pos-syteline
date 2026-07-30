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
Base64         : ew==
Decoded content: {
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

## Confirmed Contract

```text
CoAndLineInfoJson
→ Base64-encoded content
→ decoded content parsed as JSON object / JObject
→ schema validation and Customer Order processing
```

`MessageCode = 0` does not establish business success. Read and parse `CoResult`. The failure branch remains a string containing a JSON array with `Status = Fail` and exact key `ErrrorMessage`.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
```

## Current Unknowns

```text
- exact JSON property names and nesting
- required header and line fields
- co_num generation behavior
- success CoResult shape
- atomicity
```

## Next Step Only

Repeat the same read-only `dbo.co_mst` query used after probe 1 and send the complete result, including an empty result.

Do not invoke `CreateCoAndLines` again during this step.

The empty-object probe is prepared but not yet authorized:

```text
Raw decoded content : {}
Base64              : e30=
```

## Status

```text
Raw malformed probe              : COMPLETED
Base64 requirement               : CONFIRMED
First no-order check             : COMPLETED — ZERO ROWS
Base64 malformed JSON probe      : COMPLETED
JSON object / JObject requirement: CONFIRMED
Second no-order check            : PENDING
Empty-object probe               : NOT YET AUTHORIZED
Valid order probe                : NOT READY
Process/Reprocess                : NOT STARTED
Customer Order creation          : NOT STARTED
Controlled receive API           : NOT STARTED
```
