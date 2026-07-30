# Evidence — FormsAndObjects IDOInfo Has No Methods Section

Date: 30 July 2026

## Purpose

Record the tenant-confirmed limitation of the REST v1 IDOInfo response for `FormsAndObjects`.

## Tenant Observation

The user rechecked:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/FormsAndObjects
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

The response exposed the same `Properties` array previously captured, but no `Methods` section was present.

## Confirmed Result

```text
FormsAndObjects property metadata : available
Methods section                   : not exposed in this response
Repeating the same IDOInfo call   : not useful
```

This does not establish that `FormsAndObjects` has no methods. It establishes only that this tenant's `idoinfo/FormsAndObjects` response does not publish a `Methods` array.

## Next Read-Only Step

Use the already confirmed `IdoMethods` metadata collection instead of repeating the same IDOInfo endpoint:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethods/adv?props=CollectionName,MethodName,BaseCollectionName,MethodDesc,MethodType,TxnFlag,StoredProcName,DerOutriggerProfile,DerSpMethodsAllowed&filter=CollectionName%20%3D%20%27FormsAndObjects%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

The tenant-published `IdoMethods` contract already confirms these scalar properties are valid.

## Safety Result

```text
No FormsAndObjects method invocation
No form/object load
No CreateCoAndLines invocation
No metadata edit
No Customer Order payload
No SQL execution
```
