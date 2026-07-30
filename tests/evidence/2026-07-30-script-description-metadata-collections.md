# Evidence — Tenant Collections Whose Descriptions Contain script

Date: 30 July 2026

## Purpose

Search tenant-published IDO collection descriptions for the substring `script` after the collection-name search did not identify a production form/global script metadata source.

The request was read-only.

## Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionDesc%20LIKE%20%27%25script%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Tenant Result

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
Rows returned  : 4
```

| CollectionName | CollectionDesc | ServerName | AccessAs |
| --- | --- | --- | --- |
| `BuildApplicationMessagesScript` | Temp IDO that will hold the Derived Binary Value for the script generation | `MGCore` | `Core` |
| `Deployment` | Generate and process scripts/xml for applet deployment | `MGCore` | `Core` |
| `SLInvSequences` | Its the collection that is used in the Invoices /Credit/ Debit Memo Sequences form. It uses the inv_sequences table along with the inv_category table to take the description of the category. | `Customer` | `BaseSyteLine` |
| `SLInvSequences_IDS` | Its the collection that is used in the Invoices /Credit/ Debit Memo Sequences form. It uses the inv_sequences table along with the inv_category table to take the description of the category. | `Customer` | `BaseSyteLine` |

## Confirmed Interpretation

```text
BuildApplicationMessagesScript : temporary application-message script-generation IDO
Deployment                     : deployment script/XML processing, not application form/global script metadata
SLInvSequences                 : false positive because the word "description" contains the substring "script"
SLInvSequences_IDS             : same false-positive mechanism
```

The description-based search did not identify an obvious production form-script or global-script metadata collection.

This does not prove that form script metadata is unavailable. It may be stored under a form-oriented collection name that does not contain `Script`, or exposed through form metadata properties rather than a dedicated script collection.

## Next Read-Only Step

Discover actual tenant-published collections whose names contain `Form`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25Form%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Do not load rows from returned form collections until a candidate collection and its property contract are selected.

## Safety Result

```text
No CreateCoAndLines invocation
No script-row load
No form-row load
No metadata edit
No Customer Order payload
No SQL execution
```
