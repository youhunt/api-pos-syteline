# Evidence — CreateCoAndLines Reaches JObject Parser After Base64 Decode

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
CoAndLineInfoJson : ew==
CoResult          : blank
```

`ew==` is Base64 for the deliberately malformed decoded content `{`.

## Tenant Response

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

## Confirmed Contract Discovery

The Base64 value was accepted and decoded. The extension then attempted to read the decoded content as a Newtonsoft JSON `JObject` and failed because `{` is incomplete JSON.

Confirmed behavior:

```text
- CoAndLineInfoJson must contain Base64-encoded content.
- The decoded content must be a JSON object, not arbitrary text.
- The extension uses JObject-style parsing for the decoded payload.
- MessageCode = 0 still does not mean business success.
- CoResult contains a JSON-array string with Status = Fail.
```

The decoded payload contract is now refined to:

```text
CoAndLineInfoJson
→ Base64 decode
→ valid JSON object / JObject
→ Customer Order schema validation and processing
```

The exact JSON property names, nesting, and required values remain unknown.

## Exact Result-Key Observation

The returned failure result again uses:

```text
ErrrorMessage
```

with three consecutive `r` characters.

## Safety Interpretation

The failure occurred during JSON parsing before a complete JSON object could be processed. No valid Customer Order values or guessed schema fields were submitted.

Absence of a created Customer Order is not marked verified for this second probe until a separate read-only `dbo.co_mst` check is completed.
