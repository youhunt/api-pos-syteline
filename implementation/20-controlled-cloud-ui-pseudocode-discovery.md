# Implementation 20 — Controlled Cloud UI CreateCoAndLines Discovery

## Status

```text
Environment                         : Infor Cloud tenant
Active Customer Order path          : SL.SLCos.CreateCoAndLines
Direct-insert stored procedure      : fallback only
Form Control Utilities tab          : device sync only — stopped
Primary call-site candidate         : CustomerOrdersQuickEntry
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

## Cloud UI Correction

The tenant `Form Control > Utilities` screenshot showed only:

```text
Sync Dev from Master
Sync Master from Dev
Sync Archive from Master
Sync Master from Archive
```

That path is unrelated to Customer Order creation and is stopped. No synchronization action was executed.

## CustomerOrdersQuickEntry Candidate

The user identified `CustomerOrdersQuickEntry` and confirmed that it contains both Customer Order header data and Customer Order item/detail lines.

This is the strongest current form candidate for discovering the standard header-plus-line workflow required by SMK069. The form may invoke `SL.SLCos.CreateCoAndLines` or another standard save/event sequence; this is not yet confirmed.

## Active Discovery Plan

```text
1. Inspect CustomerOrdersQuickEntry collection definitions.
2. Confirm header and line IDO bindings.
3. Inspect form events/scripts for New, Save, Process, or Submit.
4. Identify CreateCoAndLines or the equivalent standard sequence.
5. Extract JSON construction and Base64 encoding when present.
6. Build one minimal valid DEV payload.
7. Invoke CreateCoAndLines once under controlled conditions.
8. Verify co_mst and coitem_mst.
9. Reuse the contract for SMK069 Process/Reprocess.
```

## Immediate Next Step

Open `CustomerOrdersQuickEntry` in Design Mode and capture the collection definitions showing:

```text
- primary collection;
- secondary/subcollection names;
- aliases;
- parent-child relationship, when visible.
```

Do not save, customize, check out, submit, or create an order.

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
```
