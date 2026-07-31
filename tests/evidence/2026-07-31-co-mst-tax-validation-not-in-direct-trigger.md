# Evidence — CO Tax Validation Not Present in Direct co_mst Trigger Text

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant-confirmed result

A read-only search was executed against every trigger whose `parent_id` is `dbo.co_mst`, filtering trigger source for either:

```text
tax_code_type
taxcode
```

The result set was empty.

## Interpretation

The current tax-code error is not produced by literal tax-code validation logic written directly in a trigger definition attached to `dbo.co_mst`.

The direct trigger path likely invokes another stored procedure or generic validation routine that constructs the standard message through `MsgAppSp` / `RaiseErrorSp`.

This does not invalidate the prior tenant evidence:

```text
GetSiteContext() = DEFAULT
taxcode_mst contains PPN11%
dbo.taxcode view returns PPN11%
site comparison matches
```

## Next read-only step

Search all SQL modules for the internal message-token references used by SyteLine when describing Tax Code composite keys:

```text
@taxcode.tax_system
@taxcode.tax_code_type
@taxcode.tax_code
```

The exact caller and surrounding condition must be identified before modifying tax data, standard triggers, or validation behavior.
