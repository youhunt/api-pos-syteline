# Evidence — CreateCoAndLines Rejects Empty JSON Object as Blank Order Input

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
CoAndLineInfoJson : e30=
Decoded content   : {}
CoResult          : blank
```

`e30=` is Base64 for an empty JSON object.

## Tenant Response

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

## Confirmed Contract Discovery

The Base64 decoder and JSON-object parser both accepted the input. The method then rejected the decoded empty object at its order-input validation layer.

Confirmed behavior:

```text
- CoAndLineInfoJson must contain Base64-encoded content.
- The decoded content must be a valid JSON object / JObject.
- An empty JObject is treated as blank order input.
- MessageCode = 0 still does not establish business success.
- CoResult remains a string containing a JSON array.
- The returned Status is Fail.
```

The public processing sequence is now refined to:

```text
CoAndLineInfoJson
→ Base64 decode
→ valid JSON object / JObject parse
→ non-blank order-input validation
→ Customer Order schema validation and processing
```

## Failure Result Shape Observation

This failure branch returned only:

```json
[
  {
    "Status": "Fail",
    "Message": "The input for order creation cannot be blank"
  }
]
```

Unlike the earlier Base64 and JSON-parser failure branches, this response did not include `ErrrorMessage`. Integration code must therefore tolerate failure records where that key is absent.

## Remaining Unknowns

```text
- the top-level order property name or names
- exact JSON nesting
- required Customer Order header fields
- required Customer Order line fields
- date and numeric formats
- co_num generation behavior
- success CoResult shape
- atomicity of header and line creation
```

## Safety Interpretation

No customer, item, site, order number, date, quantity, price, or guessed schema field was submitted.

Absence of a created Customer Order is not marked verified for this probe until a separate read-only `dbo.co_mst` check is completed.
