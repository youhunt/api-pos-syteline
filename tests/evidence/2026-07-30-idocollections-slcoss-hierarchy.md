# Evidence — SLCos Collection Hierarchy and Extension Owner

Date: 30 July 2026

## Read-Only Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,Extends,ExtClassName,ExtClassNamespace,CustomAssemblyName,ServerName,AccessAs,OutriggerProfile,DerServerPlusCollection,ReplaceFlag,DevelopmentFlag&filter=CollectionName%20%3D%20%27SLCos%27%20OR%20CollectionName%20%3D%20%27SLCos_FT%27%20OR%20CollectionName%20%3D%20%27ZIT_SLCos%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

The response returned `Message = Success`, `MessageCode = 0`, and three collection rows.

## Confirmed Collection Rows

| Collection | Extends | Ext Class | Namespace | Assembly | Server | Access As | Server Plus Collection |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `SLCos` | NULL | `SLCos` | `Customer` | `Customer` | `Customer` | `BaseSyteLine` | `Customer.SLCos` |
| `SLCos_FT` | `SLCos` | NULL | NULL | NULL | `WarehouseMobility` | `BaseSyteLine` | `WarehouseMobility.SLCos_FT` |
| `ZIT_SLCos` | `SLCos` | NULL | NULL | NULL | `ZITSL` | `ZIT` | `ZITSL.ZIT_SLCos` |

Additional confirmed values:

```text
SLCos CollectionDesc : Customer Orders and a lot of related forms
SLCos ReplaceFlag    : NULL
SLCos_FT ReplaceFlag : 0
ZIT_SLCos ReplaceFlag: 0
DevelopmentFlag      : 0 on all three rows
OutriggerProfile     : NULL on all three rows
```

## Confirmed Hierarchy

```text
SLCos
├── SLCos_FT extends SLCos
└── ZIT_SLCos extends SLCos
```

`SLCos` is the base Customer Order collection. It is directly associated with:

```text
Extension class name : SLCos
Namespace            : Customer
Custom assembly      : Customer
Server project       : Customer
Server-plus identity : Customer.SLCos
```

`SLCos_FT` and `ZIT_SLCos` both inherit from `SLCos` and do not publish their own extension class, namespace, or custom assembly in the returned metadata.

## Technical Decision

The best tenant-supported implementation lead for `CreateCoAndLines` is the base extension class:

```text
Customer.SLCos
Assembly: Customer
```

This confirms the collection hierarchy and extension owner metadata. It does not expose the extension source code or the exact `CoAndLineInfoJson` schema.

## Safety Result

No business method was invoked. No Customer Order was created or modified. No standard metadata was edited.