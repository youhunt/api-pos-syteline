# Evidence — EventActions IDOInfo Properties

Date: 30 July 2026

## Purpose

Identify the tenant-published `EventActions` properties that can be searched read-only for a standard metadata call site of:

```text
SLCos.CreateCoAndLines
```

## Relevant Published Properties

The tenant `EventActions` IDOInfo response includes:

```text
ActionType                  : Byte, required
DerActionTypeText           : String(50), read-only
Parameters                  : String(MAX)
ExpandedParameters          : String(4000), read-only
SubstitutedParameters       : String(4000), read-only
EventName                   : String(50), read-only
EventHandlerSequence        : Short Integer, read-only
Sequence                    : Short Integer, required
Description                 : String(40)
EventHandlerRowPointer      : GUID, required
RowPointer                  : GUID, read-only
AccessAs                    : String(50), read-only
DerAccessAs                 : String(50)
EventActionVariableAccess   : CONTAINS
IsEventActionRevision       : Byte
EventHandlerRevisionRowPointer : GUID, read-only
```

Additional audit, revision, workflow, note, and UDF properties are also published.

## Technical Interpretation

The strongest first search field is the raw action configuration:

```text
Parameters
```

Context fields to return with each match are:

```text
EventName
EventHandlerSequence
Sequence
Description
ActionType
DerActionTypeText
Parameters
ExpandedParameters
SubstitutedParameters
AccessAs
EventHandlerRowPointer
RowPointer
```

`ExpandedParameters` and `SubstitutedParameters` are derived/read-only views. They remain later fallback search fields if the raw `Parameters` search returns no rows.

No action-type meaning is inferred from the numeric `ActionType` value before tenant rows are returned.

## Next Read-Only Step

Search only:

```text
EventActions.Parameters LIKE '%CreateCoAndLines%'
```

Do not query revisions or derived parameter fields in the same step.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No event-action edit
No metadata change
No Process/Reprocess implementation
```
