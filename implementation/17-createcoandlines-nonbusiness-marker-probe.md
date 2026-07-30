# Implementation 17 — CreateCoAndLines Non-Business Marker Probe

## Status

```text
Environment                         : DEV
Empty-object probe                  : COMPLETED
Third read-only co_mst check        : COMPLETED — ZERO ROWS
Non-business marker probe           : COMPLETED
Specific order structure required   : CONFIRMED
Marker-probe no-order check         : PENDING
Exact business JSON schema          : NOT YET CONFIRMED
Valid Customer Order probe          : NOT READY
Customer Order creation             : NOT STARTED
```

## Confirmed Gate

```text
Environment                    : DEV
Empty-object probe             : completed
Third read-only co_mst check   : completed
Rows returned                  : 0
Unexpected Customer Order      : not found
```

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-empty-object-probe-no-order-created.md
```

## Purpose

Determine whether the message `The input for order creation cannot be blank` is triggered only because the JSON object has no members, or because a specific top-level order member or structure is missing.

The `probe` member is not part of the confirmed business schema. It was used only as a non-business marker.

## Completed Marker Probe

Decoded JSON:

```json
{"probe":true}
```

Base64:

```text
eyJwcm9iZSI6dHJ1ZX0=
```

Tenant response:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "eyJwcm9iZSI6dHJ1ZX0=",
    "[{\"probe\":true,\"Status\":\"Fail\",\"Message\":\"The input for order creation cannot be blank\"}]"
  ],
  "ReturnValue": null
}
```

## Confirmed Discovery

The marker object was non-empty and passed both Base64 decoding and `JObject` parsing, but the method still returned:

```text
Status  : Fail
Message : The input for order creation cannot be blank
```

Therefore:

```text
- the blank-order test is not merely checking whether the JObject contains any property;
- an arbitrary top-level property does not satisfy the order-input contract;
- one or more specific top-level business members or a specific nested order structure are required;
- the exact required names and nesting remain unconfirmed;
- MessageCode = 0 is not business success;
- CoResult remains a string containing a JSON array.
```

The failure result preserved the submitted marker and added `Status` and `Message`:

```json
{
  "probe": true,
  "Status": "Fail",
  "Message": "The input for order creation cannot be blank"
}
```

This confirms echo/augmentation behavior for this failure branch only. It does not establish the success-result contract.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-nonbusiness-marker-blank-order-failure.md
```

## Confirmed Public Processing Sequence

```text
CoAndLineInfoJson
1. Base64 decode
2. parse decoded content as JSON object / JObject
3. locate and validate the expected non-blank order structure
4. validate Customer Order schema and values
5. run Customer Order and line creation processing
```

## Remaining Unknowns

```text
- exact required top-level order member name or names
- exact JSON nesting
- required Customer Order header fields
- required Customer Order line fields
- accepted date and numeric formats
- whether co_num is supplied or generated
- success CoResult shape
- atomicity of header and line creation
- whether another standard validation method must run first
```

## Current Small Step — Read-Only No-Order Check

Run the same recent-order query after the marker probe:

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

## Safety Boundary

```text
- No valid Customer Order payload has been submitted.
- No customer, item, site, order number, date, quantity, or price value has been submitted.
- Do not guess a business-schema member yet.
- Do not create Process/Reprocess logic.
- Do not import CSV or create the controlled receive API method.
- Do not mark the marker probe as no-order verified until the SQL result is returned.
```
