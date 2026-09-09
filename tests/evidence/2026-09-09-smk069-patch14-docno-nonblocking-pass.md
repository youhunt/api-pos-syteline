# SMK069 Shipment Patch 14 Rev.2 — DOC_NO non-blocking verification PASS

Date: 2026-09-09
Scope: Shipment Outbound SyteLine → POS API
Tenant UI: SMK Query Select Execution

## Verification result

Tenant Query Select returned:

```text
DN_No_Type        DocNoNonBlocking   EmptyStringJson
nvarchar          PASS               PASS
```

Interpretation:

- `SMK069BuildShipmentJsonSp.@DN_No` remains a string type and supports prefixed DN values such as `P96331`;
- Patch 14 Rev.2 marker `SMK069-DOC-NONBLOCKING-R2` is present in the installed tenant procedure;
- missing `DOC_NO` is normalized to an empty JSON string instead of remaining a hard-stop condition.

Therefore the previous local Build failure:

```text
Shipment DN P96331 tidak mempunyai DOC_NO/Customer Order.
```

is considered fixed at the Build layer.

## Important limitation

This verification does **not** prove the full Shipment send path yet. Independent shared blockers remain:

```text
P96330 / P96332
HTTP 404 page not found

SMK069CompleteShipmentSendSp:36
Error converting data type nvarchar to bigint
```

Do not reset/retry Shipment solely because Patch 14 passed. First fix/verify the common Complete + endpoint path, then run one controlled DN with Max/Run = 1.

## Query Select compatibility

Tenant `SMK Query Select Execution` rejects procedural batch statements such as:

```text
DECLARE
SET
EXEC
BEGIN/END
GO
```

Diagnostics for this tenant should therefore prefer a single pure `SELECT` statement.
