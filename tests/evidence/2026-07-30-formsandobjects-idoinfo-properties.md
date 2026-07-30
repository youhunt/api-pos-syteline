# Evidence — FormsAndObjects IDOInfo Properties

Date: 30 July 2026

## Purpose

Record the tenant-published property contract for `FormsAndObjects`, selected from tenant metadata because its description is:

```text
Wrapper for FormControl and FormSync
```

The IDOInfo request was read-only.

## Relevant Published Properties

The tenant exposes a utility-style contract including:

```text
DerObjectName                 : String(255)
DerObjectType                 : Short Integer
DerObjectTypeStr              : String(100)
DerRefObjName                 : String(255)
DerRefObjType                 : String(255)
DerSecondaryObjectName        : String(255)
DerTertiaryObjectName         : String(255)
DerScopeNameStr               : String(255)
DerScopeType                  : Byte
DerScopeTypeStr               : String(255)
DerCurrentConfiguration       : String(255)
DerSourceConfiguration        : String(128)
DerTargetConfiguration        : String(128)
DerAction                     : Long Integer
DerProcessInformation         : Long Integer
DerXMLData                    : String(1000)
DerBinaryData                 : Binary
Upload                        : Binary
Download                      : Binary
DerOutputText                 : String(10000)
DerCommandLinks               : String(1073741823)
DerExplanation                : String(1073741823)
DerInstruction                : String(1073741823)
LicenseDocument               : String(1073741823), required
RowPointer                    : GUID, read-only
```

Additional derived status, logging, message, source-control, workflow, audit, and UDF properties are also published.

## Confirmed Interpretation

`FormsAndObjects` does not expose an obvious persistent form-definition property such as:

```text
FormName
Script
EventName
MethodToCall
Parameters
```

Its published properties instead describe a wrapper/utility contract for selecting objects, processing actions, transferring binary/XML data, and returning output or diagnostics.

Therefore:

```text
- do not filter FormsAndObjects directly for CreateCoAndLines;
- do not assume DerXMLData or DerBinaryData contains form source;
- inspect the collection's tenant-published method list before loading or invoking anything.
```

## Next Read-Only Step

Obtain the method metadata/list for `FormsAndObjects`. No method should be invoked. The purpose is only to identify whether a read/export/get-object method exists for form definitions or synchronized form objects.

## Safety Result

```text
No FormsAndObjects row load
No FormsAndObjects method invocation
No CreateCoAndLines invocation
No form or script edit
No Customer Order payload
No SQL execution
```
