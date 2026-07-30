# Evidence — DEV Runtime Test Boundary

Date: 30 July 2026

## User Confirmation

```text
Environment                         : DEV
Disposable Customer Order testing  : ALLOWED
```

## Decision

A controlled runtime probe of `SL.SLCos.CreateCoAndLines` may be designed for this DEV tenant.

The first probe must use deliberately malformed JSON so the request is expected to fail during payload parsing before valid Customer Order business data can be created.

## Safety Rules

```text
- Do not use production customer/order values.
- Do not send a valid Customer Order payload yet.
- Do not create Process/Reprocess logic yet.
- Do not import CSV or expose the controlled receive API yet.
- Capture the complete HTTP status and response body.
- Verify standard Customer Order data after any invocation before declaring the probe safe.
```

## Current Result

```text
Environment gate              : PASSED
Runtime method invocation      : NOT YET EXECUTED
Customer Order creation        : NOT STARTED
Exact JSON contract            : NOT YET CONFIRMED
```
