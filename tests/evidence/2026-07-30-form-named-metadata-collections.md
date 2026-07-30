# Evidence — Tenant Collections Whose Names Contain Form

Date: 30 July 2026

## Purpose

Discover tenant-published IDO collections whose `CollectionName` contains `Form` so a real form-metadata source can be selected without guessing.

The request was read-only.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25Form%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Result

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
Rows returned  : many
```

The broad substring search returned many unrelated collections because `Form` also occurs inside words such as:

```text
Performance
Formula
Information
Format
ProForma
```

It also returned report, testing, configuration, finance, quality, and other business collections that are not form-definition metadata.

## Relevant Tenant-Published Candidates

| CollectionName | CollectionDesc | ServerName | AccessAs | Interpretation |
| --- | --- | --- | --- | --- |
| `FormsAndObjects` | Wrapper for FormControl and FormSync | `MGCore` | `Core` | strongest candidate for classic form/object metadata |
| `FormAliases` | NULL | `MGCore` | `Core` | form alias metadata only |
| `AppForms` | IDO for Widget Forms | `MGCore` | `Core` | widget-form metadata, not necessarily classic SyteLine forms |
| `DocTypeFormProperties` | NULL | `MGCore` | `Core` | document-type form properties; secondary candidate |
| `WSFormExtensionHints` | NULL | `MGCore` | `Core` | extension hints; not selected before its property contract is known |

## Selection Decision

The strongest next candidate is:

```text
FormsAndObjects
```

Reason:

```text
CollectionDesc = Wrapper for FormControl and FormSync
ServerName     = MGCore
AccessAs       = Core
```

This description directly links the collection to Mongoose form control/synchronization infrastructure. It is more relevant to locating form definitions, scripts, events, or object metadata than `AppForms`, which is explicitly limited to widget forms, or `FormAliases`, which appears limited to aliases.

This is only candidate selection. No claim is made yet that `FormsAndObjects` exposes script text or contains `CreateCoAndLines`.

## Next Read-Only Step

Read the tenant-published property contract:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/FormsAndObjects
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Do not load form rows until searchable properties are confirmed.

## Safety Result

```text
No CreateCoAndLines invocation
No form-row load
No script-row load
No metadata edit
No Customer Order payload
No SQL execution
```
