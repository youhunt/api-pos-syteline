# Evidence — FormsAndObjects IdoMethods List

Date: 30 July 2026

## Purpose

Record the tenant-published method metadata for `FormsAndObjects` without invoking any method or loading any form/object definition.

## Read-Only Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethods/adv?props=CollectionName,MethodName,BaseCollectionName,MethodDesc,MethodType,TxnFlag,StoredProcName,DerOutriggerProfile,DerSpMethodsAllowed&filter=CollectionName%20%3D%20%27FormsAndObjects%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Result

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
Rows returned  : 37
MethodType 2   : 17
MethodType 3   : 20
TxnFlag 0      : 37
StoredProcName : NULL for all 37 rows
BaseCollection : FormsAndObjects for all 37 rows
```

## Published Methods

```text
ArchiveConfigured
CheckedOutObjects
ClearFormSyncLog
DeleteErrorMessages
DummyMethod
ExportSettings
FormControlCustomLoad
FormControlDeviceTypesUpdate
FormControlListCustomLoad
FormReferencedObjects
FormSyncAquireResponses
FormSyncCheckConfigs
FormSyncFixes
FormSyncLoadConfigurations
FormSyncLog
FormSyncTemplatesConfigured
GetActionText
GetDeferredPromptCount
GetErrorMessages
GetObjectStatus
GetUtilitiesOutput
ImportSettings
LoadDesignerObjectTypes
LoadObjectAndScopeTypes
LoadUpgradeEntries
MasterConfigured
TemplateConfigured
TreeLoadObjects
UtilitiesGeneratePseudoCode
UtilitiesGeneratePseudoCode2
UtilitiesLicenseFormList
UtilitiesListNames
UtilitiesLoadGroupOrUser
UtilitiesLoadObjects
UtilitiesLoadObjects2
UtilitiesLoadObjectTypes
UtilitiesLoadScopeTypes
```

## Most Relevant Read/Discovery Candidates

| Method | Tenant description | Initial relevance |
| --- | --- | --- |
| `FormControlListCustomLoad` | Load drop down lists of forms or objects | Lists selectable forms/objects |
| `FormReferencedObjects` | Load referenced objects based on form | Discovers dependencies of a selected form |
| `TreeLoadObjects` | Load individual objects for Utilities tree | Loads object entries used by utilities UI |
| `UtilitiesListNames` | Get names of objects for drop down lists on Utilities tab | Lists object names for utilities workflow |
| `UtilitiesLoadObjects` | Load objects for utilities form | Loads selected objects |
| `UtilitiesLoadObjects2` | Load objects for utilities form | Alternate/newer object-load candidate; relationship not yet confirmed |
| `UtilitiesGeneratePseudoCode` | Generate pseudo code for object(s) and store output in SQL temp table | Strong candidate for readable object/form representation |
| `UtilitiesGeneratePseudoCode2` | Generate pseudo code for object(s) and store output in SQL temp table | Second pseudo-code candidate; relationship not yet confirmed |
| `GetUtilitiesOutput` | NULL | Likely output retrieval candidate by name only; not yet confirmed |

## Controlled Interpretation

The method names and descriptions suggest this possible workflow:

```text
UtilitiesListNames
→ UtilitiesLoadObjects / UtilitiesLoadObjects2
→ UtilitiesGeneratePseudoCode / UtilitiesGeneratePseudoCode2
→ GetUtilitiesOutput
```

This is an inference from tenant-published names and descriptions. It is not yet a confirmed invocation sequence.

The pseudo-code methods are currently the strongest metadata candidates for obtaining a readable representation that may contain references such as `CreateCoAndLines`. No method may be invoked before its parameter contract is inspected.

## Next Read-Only Step

Load parameter metadata for both pseudo-code candidates so their contracts can be compared without choosing or invoking either one:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethodParameters/adv?props=CollectionName,MethodName,ParameterName,Sequence,DataType,InputFlag,OutputFlag,MessageFlag&filter=CollectionName%20%3D%20%27FormsAndObjects%27%20AND%20MethodName%20LIKE%20%27UtilitiesGeneratePseudoCode%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Safety Result

```text
No FormsAndObjects method invocation
No pseudo-code generation
No SQL temp-table generation
No form/object load
No CreateCoAndLines invocation
No metadata edit
No Customer Order payload
No SQL execution by the project
```