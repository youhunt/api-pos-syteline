# Evidence — EventActionRevisions IDOInfo Properties

Date: 30 July 2026

## Purpose

Record the tenant-published property contract for `EventActionRevisions` before filtering revision rows for a possible reference to:

```text
CreateCoAndLines
```

The metadata request was read-only.

## Relevant Published Properties

```text
ExpandedParameters      : String(4000), read-only
ActionType              : Byte
Description             : String(40)
EventHandlerRowPointer  : GUID
Parameters              : String(3800)
Sequence                : Short Integer
RowPointer              : GUID, read-only
CreateDate              : Date, read-only
CreatedBy               : String(30), read-only
RecordDate              : Date, read-only
UpdatedBy               : String(30), read-only
```

Additional UDF and audit properties are also published.

## Technical Interpretation

The strongest first search field is the revision's raw configuration:

```text
Parameters
```

`ExpandedParameters` is a derived/read-only fallback and must be searched only in a later separate step if the raw revision search returns no rows.

No meaning is assigned to numeric `ActionType` values before an actual tenant row is returned.

## Next Read-Only Step

Filter `EventActionRevisions.Parameters` for `CreateCoAndLines` and return the action context fields. Do not execute or modify any action or revision.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No revision-row load beyond IDOInfo
No metadata edit
No SQL execution
```