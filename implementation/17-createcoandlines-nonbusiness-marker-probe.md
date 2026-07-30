# Implementation 17 — CreateCoAndLines Non-Business Marker Probe

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

Determine whether the message `The input for order creation cannot be blank` is triggered only because the JSON object has no members, or because a specific top-level order member is missing.

This probe does not claim that `probe` is part of the business schema. It is only a non-business marker.

## Payload

Decoded JSON:

```json
{"probe":true}
```

Base64:

```text
eyJwcm9iZSI6dHJ1ZX0=
```

## Postman Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/method/SLCos/CreateCoAndLines
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Params:

```text
Key   : parms
Value : eyJwcm9iZSI6dHJ1ZX0=,
```

The trailing comma supplies the blank initial value for `CoResult`.

## Expected Evidence

Capture the complete response:

```text
HTTP status
Message
MessageCode
ReturnValue
Parameters
```

## Safety Boundary

```text
- Use exactly the documented Base64 value.
- Do not add customer, item, site, order number, date, quantity, price, or another business field.
- Do not submit a second payload in the same step.
- Do not create Process/Reprocess logic.
- Run a separate read-only recent-order check after the response.
```