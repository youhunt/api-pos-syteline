# Evidence — Tenant Collections Whose Names Contain Script

Date: 30 July 2026

## Purpose

Discover actual tenant-published IDO collections whose `CollectionName` contains `Script`, without guessing form-script or global-script collection names.

The request was read-only.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25Script%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Result

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
Rows returned  : 3
```

| CollectionName | CaptionOrName | CollectionDesc | ServerName | AccessAs |
| --- | --- | --- | --- | --- |
| `BuildApplicationMessagesScript` | `FORMAT(oApplicationMessages)` | Temp IDO that will hold the Derived Binary Value for the script generation | `MGCore` | `Core` |
| `UTScripts` | `UTScripts` | NULL | `UnitTesting` | `BaseSyteLine` |
| `UTScriptSelections` | `UTScriptSelections` | NULL | `UnitTesting` | `BaseSyteLine` |

## Confirmed Interpretation

```text
BuildApplicationMessagesScript : temporary application-message script-generation IDO
UTScripts                      : unit-testing collection
UTScriptSelections             : unit-testing selection collection
```

The name-based search did not identify an obvious production form-script or global-script metadata collection.

This does not prove that script metadata is unavailable. A relevant collection may have a name that does not contain `Script` while its caption or description does.

## Next Read-Only Step

Search tenant collection descriptions for `script`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionDesc%20LIKE%20%27%25script%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Safety Result

```text
No CreateCoAndLines invocation
No script-row load
No metadata edit
No Customer Order payload
No SQL execution
```
