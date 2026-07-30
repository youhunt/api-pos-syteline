# Evidence — SL.SLCos Header Method List

## Date

```text
30 July 2026
```

## Tenant Object

```text
IDO : SL.SLCos
Role: Standard Customer Order header IDO
```

## Discovery Result

The tenant's IDO Methods list for `SL.SLCos` was reviewed without creating, editing, resynchronizing, saving, or executing any standard method.

The complete list contains many inquiry, status, copy, validation, reporting, and processing methods. The methods most relevant to new Customer Order creation are:

| Method | Method Type | Stored Procedure | Transactional | Initial Relevance |
| --- | --- | --- | ---: | --- |
| `CreateCoAndLines` | Extension Class - Standard Method | blank | 0 | Strong candidate for combined header-and-line creation; parameters still unknown |
| `NewCustomerOrderValidSp` | Extension Class - Standard Method | `NewCustomerOrderValidSp` | 1 | Validates a new Customer Order and may return a default `co_num` when none is supplied |
| `CreateCoColSp` | Extension Class - Standard Method | `CreateCoColSp` | 1 | Candidate header/collection creation method; parameters still unknown |
| `CoCustomerValidSp` | Extension Class - Standard Method | `CoCustomerValidSp` | 1 | Validates customer and populates downstream header defaults |
| `CoCustomerValid2Sp` | Extension Class - Standard Method | `CoCustomerValid2Sp` | 0 | Additional customer validation candidate |
| `CoCustSeqValidSp` | Extension Class - Standard Method | `CoCustSeqValidSp` | 1 | Validates customer ship-to sequence |
| `VerifyCoCustNumSp` | Extension Class - Standard Method | `VerifyCoCustNumSp` | 1 | Customer/order verification candidate |
| `CoNextKeyDelSp` | Extension Class - Standard Method | `CoNextKeyDelSp` | 1 | Appears related to Customer Order key handling; purpose must not be assumed from name alone |
| `SumCoSp` | Extension Class - Standard Method | `SumCoSp` | 1 | Recalculation/summary method, likely post-create rather than primary creation |

## Important Decision

The method list confirms that the tenant provides dedicated standard Customer Order methods. It does **not** yet establish which method or method sequence must be used by SMK069.

Do not implement the custom Process/Reprocess method based only on method names.

## Current Best Candidate for Parameter Inspection

```text
CreateCoAndLines
```

Reason:

```text
- method name explicitly references both Customer Order header and lines;
- it is a Standard Method on SL.SLCos;
- it may provide a supported single-call creation boundary reusable by form and API;
- its parameter contract and internal expectations are still unknown.
```

## Next Evidence Required

Open `CreateCoAndLines` in IDO Methods and capture:

```text
Method Type
Transactional setting
Stored Procedure / implementation reference
all parameter names
parameter sequence
user data types
output properties, if any
```

Do not execute or modify the standard method.