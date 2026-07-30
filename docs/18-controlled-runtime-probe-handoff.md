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

## Completed Contract Probes

### Probe 1 — Raw `{`

Confirmed that `CoAndLineInfoJson` must contain Base64-encoded content.

### Probe 2 — `ew==`

```text
Decoded content : {
```

Confirmed that decoded content is parsed as a JSON object / Newtonsoft `JObject`.

### Probe 3 — `e30=`

```text
Decoded content : {}
```

Tenant response:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "e30=",
    "[{\"Status\":\"Fail\",\"Message\":\"The input for order creation cannot be blank\"}]"
  ],
  "ReturnValue": null
}
```

Confirmed:

```text
- Base64 decoding succeeded.
- JObject parsing succeeded.
- An empty object is treated as blank order input.
- Non-blank order content is required before deeper schema processing.
- MessageCode = 0 does not establish business success.
- CoResult is still a string containing a JSON array.
```

This failure branch does not include `ErrrorMessage`. Failure parsers must therefore tolerate that key being absent.

## Confirmed Processing Sequence

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ non-blank order-input validation
→ Customer Order schema validation
→ Customer Order and line processing
```

## Completed No-Order Verifications

```text
Probe 1 check : zero rows
Probe 2 check : zero rows
SQL errors    : none
```

The third no-order verification after the `{}` probe is still pending.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
tests/evidence/2026-07-30-createcoandlines-empty-object-blank-order-failure.md
```

## Current Unknowns

```text
- top-level order member name or names
- exact JSON nesting
- required header fields
- required line fields
- date and numeric formats
- co_num generation behavior
- success CoResult shape
- atomicity of header and line creation
```

## Next Step Only

Run the same read-only recent-order query after the empty-object probe:

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

Send the complete result, including an empty result.

Do not invoke `CreateCoAndLines` again during this step.

## Status

```text
Raw malformed probe                : COMPLETED
Base64 requirement                 : CONFIRMED
First no-order check               : COMPLETED — ZERO ROWS
Base64 malformed JSON probe        : COMPLETED
JSON object / JObject requirement  : CONFIRMED
Second no-order check              : COMPLETED — ZERO ROWS
Empty-object probe                 : COMPLETED
Non-blank order-input requirement  : CONFIRMED
Third no-order check               : PENDING
Non-empty contract probe           : NOT YET AUTHORIZED
Valid order probe                  : NOT READY
Process/Reprocess                  : NOT STARTED
Customer Order creation            : NOT STARTED
Controlled receive API             : NOT STARTED
```

## Safety Boundary for the Current Step

```text
- Do not submit another payload.
- Do not add customer, item, order, site, date, quantity, or price data.
- Do not guess business schema fields.
- Do not create Process/Reprocess logic.
- Confirm the third no-order check before advancing.
```
