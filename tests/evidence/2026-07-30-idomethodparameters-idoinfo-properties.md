# Evidence — IdoMethodParameters IDOInfo Properties

Date: 30 July 2026

## Successful Read-Only Metadata Request

The REST v1 IDOInfo fallback returned the property metadata for `IdoMethodParameters`.

No business method was invoked and no Customer Order data was created or changed.

## Properties Relevant to Method Parameter Direction

```text
CollectionName
MethodName
ParameterName
Sequence
DataType
InputFlag
OutputFlag
MessageFlag
```

The response also exposes supporting metadata such as:

```text
SpDataType
SpDataLength
SpDataScale
DevelopmentFlag
CreateDate
CreatedBy
RecordDate
UpdatedBy
RowPointer
_ItemId
_ItemWarnings
```

## Confirmed Decision

`IdoMethodParameters` can be queried read-only to determine the direction flags for the two parameters of:

```text
IDO    : SLCos
Method : CreateCoAndLines
```

The next read-only request will load only these properties:

```text
CollectionName
MethodName
ParameterName
Sequence
DataType
InputFlag
OutputFlag
MessageFlag
```

with a filter for `CollectionName = 'SLCos'` and `MethodName = 'CreateCoAndLines'`.

## Safety

`CreateCoAndLines` has not been executed. Customer Order creation remains not started.
