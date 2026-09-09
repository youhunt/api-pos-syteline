# Implementation 16 — Controlled CreateCoAndLines Runtime Probe

## Status

```text
Environment                       : DEV
Disposable testing                : ALLOWED
Raw malformed probe               : COMPLETED
Base64 requirement                : CONFIRMED
Malformed decoded JSON probe      : COMPLETED
Decoded payload type              : JSON object / JObject
Empty-object probe                : COMPLETED
Non-blank order input             : CONFIRMED
No-order checks after probes 1–3  : COMPLETED — ZERO ROWS
Exact business JSON schema        : NOT YET CONFIRMED
Valid Customer Order probe        : NOT READY
Customer Order creation           : NOT STARTED
```

## Confirmed Method Contract

```text
IDO             : SLCos
Method          : CreateCoAndLines
Method Type     : Extension Class - Standard Method
Implementation  : Customer.SLCos
Assembly        : Customer — Binary Only
Transactional   : false
```

```text
CoAndLineInfoJson : input-only
CoResult          : input/output + message
```

## Confirmed Runtime Sequence

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ reject blank order input
→ validate business schema
→ Customer Order and line processing
```

## Probe Results

### Probe 1

```text
Input  : raw {
Result : invalid Base64
```

### Probe 2

```text
Input           : ew==
Decoded content : {
Result          : JObject parser failure
```

### Probe 3

```text
Input           : e30=
Decoded content : {}
Result          : Status=Fail
Message         : The input for order creation cannot be blank
```

## Result Handling

```text
- MessageCode = 0 confirms method-layer invocation only.
- Business success must be read from CoResult.
- CoResult is a string containing a JSON array.
- Failure records may omit ErrrorMessage.
- Earlier branches returned the exact key ErrrorMessage with three r characters.
```

## Completed Read-Only Verifications

The standard recent-order query returned zero rows after each of the three probes.

```text
Probe 1 check : zero rows
Probe 2 check : zero rows
Probe 3 check : zero rows
SQL errors    : none
```

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-empty-object-blank-order-failure.md
tests/evidence/2026-07-30-createcoandlines-empty-object-probe-no-order-created.md
```

## Remaining Unknowns

```text
- top-level business member names
- exact header/line nesting
- required header fields
- required line fields
- date and numeric formats
- co_num generation behavior
- success CoResult shape
- atomicity
```

## Next Step

Continue with:

```text
implementation/17-createcoandlines-nonbusiness-marker-probe.md
```

That step uses one non-business marker object only to distinguish empty-object validation from missing-business-member validation. No valid order data is included.