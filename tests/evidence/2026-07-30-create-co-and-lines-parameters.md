# Evidence — SL.SLCos CreateCoAndLines Parameters

Date: 30 July 2026

## Tenant Object

```text
IDO Name      : SLCos
Method Name   : CreateCoAndLines
Method Type   : Extension Class - Standard Method
Transactional : unchecked / false
Stored Proc.  : not applicable / blank
```

## Parameters Shown by Tenant

| Sequence | Parameter Name | User Data Type |
| ---: | --- | --- |
| 1 | `CoAndLineInfoJson` | `VARIANT` |
| 2 | `CoResult` | `VARIANT` |

The tenant screen does not expose the input/output direction in the visible parameter grid.

The **Custom Load Method Output Properties** area is blank, which is expected because `CreateCoAndLines` is a standard method rather than a custom load method.

## Current Interpretation

The parameter names strongly suggest the following contract, but direction is not yet tenant-verified:

```text
CoAndLineInfoJson : likely JSON input containing Customer Order header and line data
CoResult          : likely returned result/status payload
```

This interpretation must not yet be treated as the final API contract. The exact JSON schema, output direction, success response, error response, Customer Order number behavior, and transactional behavior still require controlled verification.

## Safety Decision

No standard method was modified, resynchronized, saved, or executed while collecting this evidence.

Do not implement the custom Process/Reprocess method until the public contract of `CreateCoAndLines` has been verified.