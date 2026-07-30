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
Empty-object probe                 : COMPLETED
Non-blank order-input requirement  : CONFIRMED
Third no-order check               : PENDING
Non-empty contract probe           : NOT YET AUTHORIZED
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

## Probe 1 — Raw Malformed Input

Submitted:

```text
CoAndLineInfoJson : {
CoResult          : blank
```

Result:

```text
Status : Fail
Error  : input is not valid Base64
```

Confirmed:

```text
CoAndLineInfoJson must contain Base64-encoded content.
```

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
tests/evidence/2026-07-30-createcoandlines-raw-probe-no-order-created.md
```

## Probe 2 — Base64 for Malformed JSON

Submitted:

```text
CoAndLineInfoJson : ew==
Decoded content   : {
CoResult          : blank
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

Confirmed:

```text
The decoded content is parsed as a JSON object / Newtonsoft JObject.
```

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-base64-malformed-json-parser-failure.md
tests/evidence/2026-07-30-createcoandlines-base64-malformed-probe-no-order-created.md
```

## Probe 3 — Empty JSON Object

Submitted:

```text
CoAndLineInfoJson : e30=
Decoded content   : {}
CoResult          : blank
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
- An empty JObject is treated as blank order input.
- The order-input validation layer requires non-blank content.
- MessageCode = 0 still does not establish business success.
- CoResult remains a string containing a JSON array.
```

This failure branch contains only:

```text
Status
Message
```

It does not contain `ErrrorMessage`, so integration code must not require that key on every failure result.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-empty-object-blank-order-failure.md
```

## Confirmed Public Processing Sequence

```text
CoAndLineInfoJson
1. Base64 decode
2. parse decoded content as JSON object / JObject
3. reject blank order input
4. validate the Customer Order payload schema
5. run Customer Order and line creation processing
```

The exact schema for steps 4 and 5 remains unconfirmed.

## Result-Handling Rules Confirmed So Far

```text
- MessageCode = 0 means the Mongoose method invocation reached the method layer.
- It does not mean Customer Order creation succeeded.
- Parse the returned CoResult string as a JSON array.
- Evaluate Status for business success or failure.
- Failure records may or may not include ErrrorMessage.
- The exact earlier key is ErrrorMessage with three consecutive r characters.
```

## Remaining Unknowns

```text
- top-level order property name or names
- exact JSON nesting
- required header fields
- required line fields
- accepted date and numeric formats
- whether co_num is supplied or generated
- success CoResult shape
- whether header and lines are created atomically
- whether another standard validation method must run first
```

## Current Small Step — Third Read-Only No-Order Check

Repeat the same recent-order query after the empty-object probe:

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

Only after this third no-order check succeeds may a later controlled probe use one non-empty, non-business marker object solely to determine whether the blank test checks object emptiness or a specific required top-level member. That later payload is not yet authorized.

## Safety Boundary

```text
- No valid Customer Order payload has been submitted.
- No customer, item, site, order number, date, quantity, or price value has been submitted.
- Do not guess business schema fields yet.
- Do not create Process/Reprocess logic.
- Do not import CSV or create the controlled receive API method.
- Do not mark the empty-object probe as no-order verified until the SQL result is returned.
```
