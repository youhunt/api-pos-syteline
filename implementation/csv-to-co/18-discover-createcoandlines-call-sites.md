# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                         : DEV / Infor Cloud tenant
SL.SLCos.CreateCoAndLines discovery : PAUSED BY USER
Reason                              : undocumented payload discovery exceeded delivery tolerance
Direct-insert stored procedure      : ACTIVE IMPLEMENTATION PATH
Exact Base64 JSON schema            : NOT CONFIRMED
CreateCoAndLines invocation         : no successful business invocation
```

## Confirmed Findings Retained

```text
Method                       : SL.SLCos.CreateCoAndLines
CoAndLineInfoJson            : input-only Base64-encoded JSON object/JObject
CoResult                     : input/output message parameter
CoResult runtime form        : JSON-array string
MessageCode = 0              : framework success only
Customer Order header IDO    : SL.SLCos
Customer Order line IDO      : SL.SLCoitems
```

Controlled malformed/non-business probes created no Customer Order rows.

## CustomerOrdersQuickEntry Findings

Tenant Design Mode confirmed:

```text
Primary collection      : SLCos
Primary collection name : oSLCos
Line binding             : SLCoitems subcollection
Line collection name    : oLines
Reload after child save : enabled
```

Relationship:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

No direct form-level handler matching `CreateCoAndLines` was displayed.

`StdFormSave` includes custom `SMK_Save()`, but the complete user-provided source showed that this method only changes `Stat` to `S` when a custom request date is more than 30 days in the past. It does not construct JSON, encode Base64, invoke `CreateCoAndLines`, or create Customer Order data.

## Decision

On 31 July 2026, the user explicitly stopped this discovery path and selected direct stored-procedure processing to meet the delivery schedule.

Active work continues in:

```text
implementation/19-controlled-sp-direct-order-processing.md
```

## Boundary

```text
- Do not continue CreateCoAndLines payload guessing.
- Do not run additional malformed probes.
- Do not invoke FormSync/device synchronization.
- Preserve this document as discovery history.
- Direct SQL implementation must keep triggers and constraints enabled.
```

## Evidence

```text
tests/evidence/2026-07-31-customerordersquickentry-collection-bindings.md
tests/evidence/2026-07-31-customerordersquickentry-createcoandlines-event-search-no-match.md
tests/evidence/2026-07-31-customerordersquickentry-standard-save-events-visible.md
tests/evidence/2026-07-31-customerordersquickentry-stdformsave-responses.md
tests/evidence/2026-07-31-smk-save-source-and-direct-insert-decision.md
```
