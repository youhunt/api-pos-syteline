# Evidence — User Reconfirms CreateCoAndLines Path

Date: 31 July 2026

## Decision

The user explicitly reconfirmed that the active Customer Order creation path should continue with:

```text
SL.SLCos.CreateCoAndLines
```

The controlled direct-insert stored-procedure approach remains a fallback only.

## Cloud UI Observation

The tenant `Form Control` screenshot showed that the visible `Utilities` tab contains only device-type synchronization actions:

```text
Sync Dev from Master
Sync Master from Dev
Sync Archive from Master
Sync Master from Archive
```

This screen is not the pseudo-code/object utility surface expected from the metadata method names. No synchronization action was executed.

## Updated Discovery Plan

```text
1. Use the Form Control `Forms` tab only to enumerate tenant form names.
2. Identify the standard Customer Order entry form or another confirmed call site.
3. Retrieve/read its definition without modifying or checking out the form.
4. Extract the exact JSON-building contract used for SL.SLCos.CreateCoAndLines.
5. Build one minimal valid Base64 payload.
6. Execute one controlled DEV call and verify co_mst/coitem_mst.
7. Reuse the confirmed contract for SMK069 Process/Reprocess.
```

## Immediate Next Step

In `Form Control`:

```text
- select the Forms tab;
- keep Scope = Site;
- click Refresh List;
- capture the resulting form list;
- do not Check out, Check in, Get, Unlock, Archive, Restore, Delete, or Sync.
```

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order creation
No form checkout
No form synchronization
No metadata edit
No direct SQL execution
```
