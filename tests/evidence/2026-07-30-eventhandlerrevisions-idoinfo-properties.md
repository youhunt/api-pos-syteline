# Evidence — EventHandlerRevisions IDOInfo Properties

Date: 30 July 2026

## Purpose

Record the tenant-published property contract for `EventHandlerRevisions` and determine whether it exposes a direct searchable text field for a possible reference to:

```text
CreateCoAndLines
```

The metadata request was read-only.

## Relevant Published Properties

```text
EventActionRevisions          : CONTAINS
EventActions                  : CONTAINS
AccessAs                      : String(50)
AppliesToInitiators           : String(255)
AppliesToObjects              : String(255)
AppliesToSites                : String(255)
Description                   : String(40)
EventInitialStateRowPointer   : GUID, read-only
InitialEventActionRowPointer  : GUID, read-only
EventName                     : String(50), read-only
EventRevision                 : Long Integer, read-only
EventRevisionRowPointer       : GUID, read-only
InitialStateName              : String(50), read-only
InitialActionSequence         : Short Integer, read-only
Sequence                      : Short Integer
IgnoreFailure                 : Byte
InWorkflow                    : Byte
Suspend                       : Byte
Synchronous                   : Byte
Transactional                 : Byte
RowPointer                    : GUID, read-only
```

Additional audit and UDF properties are also published.

## Technical Interpretation

`EventHandlerRevisions` does not expose a direct call-site text property comparable to:

```text
MethodToCall
Parameters
ExpandedParameters
SubstitutedParameters
```

Its call-bearing content is represented through child collections:

```text
EventActionRevisions
EventActions
```

The relevant child revision path has already produced:

```text
EventActionRevisions.Parameters          : zero rows
EventActionRevisions.ExpandedParameters  : server rejected filter with IllegalFilterException
```

Therefore, filtering `EventHandlerRevisions` itself for `CreateCoAndLines` would require guessing an unsupported property and is not authorized.

## Next Read-Only Step

Discover tenant metadata collections whose names contain `Script` so the next candidate source can be selected from actual tenant-published collection names.

## Safety Result

```text
No CreateCoAndLines invocation
No Customer Order payload
No handler-revision row load
No metadata edit
No SQL execution
```
