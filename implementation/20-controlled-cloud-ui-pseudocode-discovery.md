# Implementation 20 — Controlled Cloud UI CreateCoAndLines Discovery

## Status

```text
Environment                         : Infor Cloud tenant
Active Customer Order path          : SL.SLCos.CreateCoAndLines
Direct-insert stored procedure      : fallback only
Form Control Utilities tab          : device sync only — stopped
Primary call-site candidate         : CustomerOrdersQuickEntry
Header collection                   : SLCos / oSLCos — confirmed
Line subcollection                  : SLCoitems / oLines — confirmed
CreateCoAndLines invocation          : not started
Exact business JSON schema          : not confirmed
```

## Confirmed Runtime Contract

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ expected nonblank order structure
→ business validation
→ Customer Order processing
```

`CoResult` is an input/output message parameter returned as a JSON-array string. Framework `MessageCode = 0` does not by itself establish business success.

## CustomerOrdersQuickEntry Binding Evidence

Design Mode confirms:

```text
Primary Collection      : SLCos
Primary Collection Name : oSLCos
Custom Load Method      : blank

Binding Type            : SubCollection Grid
Parent Collection       : primary collection
Subcollection Property  : SLCoitems
Line Collection Name    : oLines
Custom Load Method      : blank
Reload After Child Save : enabled
Update Locking          : Row
```

The form therefore uses:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

A top-level `Secondary Collection 2: SLAppsParms` is also visible, but its role has not been inspected.

This confirms the standard header/detail data model. It does not prove a `CreateCoAndLines` call. The form may persist through ordinary parent-child collection Save or through additional event/script logic.

## Active Discovery Plan

```text
1. Search CustomerOrdersQuickEntry form events/scripts for CreateCoAndLines.
2. If found, capture JSON construction, Base64 encoding, and invocation details.
3. If absent, inspect New, Save, and Quick Order Verification event sequences.
4. Determine whether the form uses CreateCoAndLines or standard SLCos/SLCoitems Save.
5. Build one minimal valid DEV payload only after the exact contract is confirmed.
6. Invoke CreateCoAndLines once under controlled conditions.
7. Verify co_mst and coitem_mst.
8. Reuse the contract for SMK069 Process/Reprocess.
```

## Immediate Next Step

Open the form-level Event Handlers/Scripts for `CustomerOrdersQuickEntry` and search for:

```text
CreateCoAndLines
```

Capture one matching handler/script with its actions or code. If the search returns no match, capture that result only.

## Safety Boundary

```text
- No production order processing.
- No CreateCoAndLines call yet.
- No form checkout or modification.
- No device synchronization.
- No direct SQL insert.
```

## Evidence

```text
tests/evidence/2026-07-31-user-reconfirms-createcoandlines-path.md
tests/evidence/2026-07-31-customerordersquickentry-selected-as-call-site-candidate.md
tests/evidence/2026-07-31-customerordersquickentry-collection-bindings.md
```