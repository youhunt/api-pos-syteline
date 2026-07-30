# Evidence — CreateCoAndLines Rejects Non-Business Marker as Blank Order Input

Date: 30 July 2026

## Environment

```text
Environment                        : DEV
Disposable Customer Order testing : allowed
```

## Invoked Method

```text
IDO    : SLCos
Method : CreateCoAndLines
```

Input parameters:

```text
CoAndLineInfoJson : eyJwcm9iZSI6dHJ1ZX0=
Decoded content   : {"probe":true}
CoResult          : blank
```

The `probe` member was deliberately chosen as a non-business marker. It is not asserted to be part of the Customer Order schema.

## Tenant Response

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

## Confirmed Contract Discovery

The payload passed Base64 decoding and `JObject` parsing. Even though the object was not empty, the method still returned:

```text
Status  : Fail
Message : The input for order creation cannot be blank
```

Confirmed observations:

```text
- The blank-order check is not merely a count-of-properties check.
- An arbitrary top-level member does not satisfy the required order-input structure.
- The method appears to require one or more specific top-level business members or a specific nested order structure.
- The exact required member names remain unconfirmed.
- MessageCode = 0 still does not establish business success.
- CoResult is a string containing a JSON array.
```

## CoResult Echo Behavior

The returned failure record preserved the submitted marker:

```json
{
  "probe": true,
  "Status": "Fail",
  "Message": "The input for order creation cannot be blank"
}
```

This indicates that at least this validation branch augments or reuses the decoded input object when constructing the `CoResult` record. This observation does not establish how success results are formed.

## Remaining Unknowns

```text
- exact required top-level order member name or names
- exact nesting for header and lines
- required header fields
- required line fields
- accepted date and numeric formats
- whether co_num is supplied or generated
- success CoResult shape
- atomicity of header and line creation
```

## Safety Interpretation

No customer, item, site, order number, date, quantity, price, or guessed business-schema property was submitted.

Absence of a created Customer Order is not marked verified for this probe until a separate read-only `dbo.co_mst` check is completed.
