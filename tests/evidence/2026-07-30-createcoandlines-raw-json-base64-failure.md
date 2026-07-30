# Evidence — CreateCoAndLines Rejects Raw JSON as Non-Base64

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
CoAndLineInfoJson : {
CoResult          : blank
```

The first parameter was deliberately malformed raw JSON. The second parameter was supplied as a blank initial in/out value.

## Tenant Response

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

## Confirmed Contract Discovery

The extension accepted the invocation at the Mongoose transport layer but returned a method-level failure in `CoResult`.

Confirmed behavior:

```text
- MessageCode = 0 does not mean the Customer Order operation succeeded.
- ReturnValue = null.
- CoResult contains a JSON-array string.
- CoResult Status = Fail.
- The error states that CoAndLineInfoJson is expected to be valid Base64 input.
```

Therefore the public input contract is now refined to:

```text
CoAndLineInfoJson = Base64-encoded content
```

The decoded content is still expected to be JSON based on the parameter name, but the exact decoded JSON schema remains unconfirmed.

## Exact Result-Key Observation

The tenant response uses the key:

```text
ErrrorMessage
```

with three consecutive `r` characters. Integration code must not silently normalize this key until success and failure result contracts are fully verified.

## Safety Interpretation

The response strongly indicates failure during Base64 decoding, before JSON contract processing. However, absence of a created Customer Order is not marked verified until a separate read-only Customer Order check is completed.

No guessed valid payload was submitted. No Process/Reprocess logic was created.