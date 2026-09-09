# Implementation 17 — CreateCoAndLines Non-Business Marker Probe

## Status

```text
Environment                         : DEV
Empty-object probe                  : COMPLETED
Third read-only co_mst check        : COMPLETED — ZERO ROWS
Non-business marker probe           : COMPLETED
Specific order structure required   : CONFIRMED
Marker-probe no-order check         : COMPLETED — ZERO ROWS
Exact business JSON schema          : NOT YET CONFIRMED
Further property-name guessing      : STOPPED
Next discovery path                 : STANDARD CALL-SITE METADATA
Valid Customer Order probe          : NOT READY
Customer Order creation             : NOT STARTED
```

## Confirmed Gate Before Marker Probe

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

## Marker-Probe No-Order Verification — Completed

The standard read-only recent-order query was executed after the marker probe.

Tenant result:

```text
SQL error                         : none
Rows returned                    : 0
Unexpected recent Customer Order : not found
```

Evidence:

```text
tests/evidence/2026-07-30-createcoandlines-marker-probe-no-order-created.md
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

## Technical Decision

Do not continue guessing business-schema property names. Four controlled probes and four zero-row no-order checks are complete. The next safe path is read-only discovery of standard tenant metadata that calls `SLCos.CreateCoAndLines`.

Continue with:

```text
implementation/18-discover-createcoandlines-call-sites.md
```

## Safety Boundary

```text
- No valid Customer Order payload has been submitted.
- No customer, item, site, order number, date, quantity, or price value has been submitted.
- Do not guess a business-schema member.
- Do not invoke CreateCoAndLines again during call-site discovery.
- Do not create Process/Reprocess logic yet.
- Do not import CSV or create the controlled receive API method.
```