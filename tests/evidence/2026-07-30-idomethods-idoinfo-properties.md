# Evidence — IdoMethods IDOInfo Properties

Date: 30 July 2026

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/IdoMethods
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Result

The REST v1 IDOInfo request succeeded and returned the published property metadata for `IdoMethods`.

Relevant method-level properties confirmed by the tenant:

```text
CollectionName
MethodName
BaseCollectionName
MethodDesc
MethodType
TxnFlag
StoredProcName
DerOutriggerProfile
DerSpMethodsAllowed
MethodParameters
MethodResultSets
DevelopmentFlag
```

Additional audit and framework properties include:

```text
CreateDate
CreatedBy
RecordDate
UpdatedBy
RowPointer
DerReadOnlyRecordFlag
InWorkflow
NoteExistsFlag
_ItemId
_ItemWarnings
```

## Important Finding

The published `IdoMethods` properties do **not** directly expose fields named like:

```text
ExtensionClass
Assembly
ImplementationClass
SourceCode
HelpUrl
JsonSchema
```

Therefore the IDOInfo response alone does not reveal the implementation class or the exact JSON schema expected by `SLCos.CreateCoAndLines`.

`MethodParameters` and `MethodResultSets` are `CONTAINS` properties. Parameter direction was already obtained separately through `IdoMethodParameters`.

## Safety Result

No business method was invoked. No Customer Order header or line was created or changed.

## Next Read-Only Step

Load only the `IdoMethods` row for:

```text
CollectionName = SLCos
MethodName     = CreateCoAndLines
```

and inspect the scalar metadata fields `MethodDesc`, `MethodType`, `TxnFlag`, `StoredProcName`, `BaseCollectionName`, `DerOutriggerProfile`, and `DerSpMethodsAllowed`.
