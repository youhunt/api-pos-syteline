# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Environment and Method

```text
Environment                        : DEV
Disposable Customer Order testing : ALLOWED
IDO                                : SL.SLCos
Method                             : CreateCoAndLines
Implementation                     : Customer.SLCos
Assembly                           : Customer — Binary Only
Transactional                      : false
```

```text
CoAndLineInfoJson : input-only
CoResult          : input/output + message
```

## Confirmed Contract

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ non-blank order-input validation
→ business schema validation
→ Customer Order and line processing
```

## Completed Probes

```text
Probe 1 : raw {  → invalid Base64
Probe 2 : ew==  → decoded {  → JObject parser failure
Probe 3 : e30=  → decoded {} → The input for order creation cannot be blank
```

## Business Result Rules

```text
- MessageCode = 0 is not business success.
- Parse CoResult as a JSON-array string.
- Evaluate Status.
- Failure records may or may not include ErrrorMessage.
```

## No-Order Verification

```text
Probe 1 check : zero rows
Probe 2 check : zero rows
Probe 3 check : zero rows
SQL errors    : none
```

No unexpected Customer Order was found in the checked 30-minute windows.

## Evidence

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-empty-object-blank-order-failure.md
tests/evidence/2026-07-30-createcoandlines-empty-object-probe-no-order-created.md
```

## Next Step Only

Follow:

```text
implementation/17-createcoandlines-nonbusiness-marker-probe.md
```

The prepared decoded object is:

```json
{"probe":true}
```

Base64:

```text
eyJwcm9iZSI6dHJ1ZX0=
```

This is only a marker to distinguish empty-object validation from missing-business-member validation. It is not asserted to be part of the Customer Order schema.

Do not add customer, item, site, order number, date, quantity, price, or another payload during the same step.