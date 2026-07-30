# Evidence — SLCos CreateCoAndLines Method Metadata Rows

Date: 30 July 2026

## Read-Only Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethods/adv?props=CollectionName,MethodName,BaseCollectionName,MethodDesc,MethodType,TxnFlag,StoredProcName,DerOutriggerProfile,DerSpMethodsAllowed&filter=CollectionName%20%3D%20%27SLCos%27%20AND%20MethodName%20%3D%20%27CreateCoAndLines%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Response Summary

The tenant returned three rows for the same effective method:

| CollectionName | MethodName | BaseCollectionName | MethodType | TxnFlag | StoredProcName | MethodDesc | DerOutriggerProfile | DerSpMethodsAllowed |
| --- | --- | --- | ---: | ---: | --- | --- | --- | ---: |
| `SLCos` | `CreateCoAndLines` | `SLCos` | 2 | 0 | NULL | NULL | NULL | 1 |
| `SLCos` | `CreateCoAndLines` | `SLCos_FT` | 2 | 0 | NULL | NULL | NULL | 1 |
| `SLCos` | `CreateCoAndLines` | `ZIT_SLCos` | 2 | 0 | NULL | NULL | NULL | 1 |

All three rows returned the same `_ItemId`:

```text
PBT=[IdoMethodsView] met.DT=[2025-10-07 15:17:30.877] met.ID=[6638ae26-ba92-4b8c-8419-df5abd478c76]
```

## Confirmed Facts

```text
CollectionName       : SLCos
MethodName           : CreateCoAndLines
MethodType           : 2
TxnFlag               : 0
StoredProcName        : NULL
MethodDesc            : NULL
DerOutriggerProfile   : NULL
DerSpMethodsAllowed   : 1
Effective base contexts:
- SLCos
- SLCos_FT
- ZIT_SLCos
```

The IDO Methods UI already identifies `MethodType = 2` for this record as **Extension Class - Standard Method**. The blank `StoredProcName` is consistent with that confirmed classification.

## Safe Interpretation

The three rows show that the same effective method metadata is represented across three collection/base contexts. Because the same `_ItemId` is returned, these are not treated as three independently confirmed implementations.

The exact inheritance/extension relationship between `SLCos`, `SLCos_FT`, and `ZIT_SLCos` is not yet confirmed. No conclusion is made yet about which layer contains the extension-class implementation.

The method row does not expose:

```text
- JSON schema
- assembly name
- extension-class name
- source code
- help/documentation reference
- success/failure result schema
```

## Safety Result

No standard method was invoked. No Customer Order header or line was created or changed.
