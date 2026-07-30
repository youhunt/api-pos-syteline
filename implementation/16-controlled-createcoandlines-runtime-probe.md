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
Second no-order check              : PENDING
Empty-object probe                 : NOT YET AUTHORIZED
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

## Current Small Step

Repeat the read-only `dbo.co_mst` recent-order query used after probe 1. Send the result, including an empty result. Do not invoke `CreateCoAndLines` again during this step.

Only after the second no-order check succeeds may a future probe submit Base64 `e30=`, which decodes to the empty JSON object `{}`. That probe is not authorized yet.
