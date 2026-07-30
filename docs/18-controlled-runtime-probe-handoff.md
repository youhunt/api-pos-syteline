# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Confirmed Safety Boundary

```text
Environment                        : DEV
Disposable Customer Order testing : ALLOWED
```

The environment gate for controlled runtime probing is passed.

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

## Completed First Runtime Probe

Submitted values:

```text
CoAndLineInfoJson : {
CoResult          : blank
```

Tenant response:

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "{",
    "[{\"ErrrorMessage\":\"The input is not a valid Base-64 string as it contains a non-base 64 character, more than two padding characters, or an illegal character among the padding characters. \",\"Status\":\"Fail\",\"Message\":\"Error occurred during customer order/line creation\"}]"
  ],
  "ReturnValue": null
}
```

## Confirmed Discovery

```text
CoAndLineInfoJson must contain Base64-encoded content.
```

The raw `{` value failed during Base64 decoding. The decoded JSON schema remains unknown.

`MessageCode = 0` means the method call reached the Mongoose method layer; it does not mean Customer Order creation succeeded. The business result must be read from `CoResult`.

Confirmed failure result shape:

```text
CoResult = string containing a JSON array
Status   = Fail
Message  = Error occurred during customer order/line creation
Key      = ErrrorMessage
```

The exact tenant key is `ErrrorMessage` with three consecutive `r` characters.

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-raw-json-base64-failure.md
```

## Current Unknowns

```text
- decoded JSON property names and nesting
- required and optional header fields
- required and optional line fields
- co_num generation behavior
- success CoResult shape
- deeper JSON validation errors
- atomicity of header and line creation
```

## Next Step Only

Perform a separate read-only verification for Customer Orders created around the first probe:

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

Send the complete result, including an empty result. If SQL reports an unavailable column, send the exact error and stop.

Do not invoke `CreateCoAndLines` again during this step.

## Prepared Future Probe — Not Yet Authorized

After no-order verification, the next malformed decoded-content probe may use:

```text
Raw content : {
Base64      : ew==
```

This is intended to pass Base64 decoding and reach JSON parsing. Do not send it yet.

## Status

```text
Environment gate              : PASSED
Raw JSON malformed probe      : COMPLETED
Base64 requirement            : CONFIRMED
No-order read-only check      : PENDING
Base64 malformed-content test : NOT YET RUN
Valid order probe             : NOT READY
Process/Reprocess              : NOT STARTED
Customer Order creation        : NOT STARTED
Controlled receive API         : NOT STARTED
```