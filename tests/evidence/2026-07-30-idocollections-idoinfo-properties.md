# Evidence — IdoCollections IDOInfo Properties

Date: 30 July 2026

## Read-Only Request

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/IdoCollections
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

## Relevant Published Properties

The tenant response confirms that `IdoCollections` exposes collection-level implementation and inheritance metadata, including:

```text
CollectionName
Caption
CaptionOrName
CollectionDesc
Extends
ExtClassName
ExtClassNamespace
CustomAssemblyName
ServerName
AccessAs
OutriggerProfile
DerServerPlusCollection
ReplaceFlag
DevelopmentFlag
DerSpMethodsAllowed
```

Related nested metadata is also exposed:

```text
Methods
Properties
Tables
Rules
DataRules
Filters
EventHandlerAppliesToObjects
```

## Significance

These properties are sufficient for a later read-only comparison of:

```text
SLCos
SLCos_FT
ZIT_SLCos
```

The next comparison can determine whether one collection extends another and whether an extension class, namespace, custom assembly, server project, access-as alias, or outrigger profile is declared.

This response does not itself identify the JSON schema accepted by `CreateCoAndLines`.

## Safety Result

No business method was invoked. No Customer Order was created or changed.