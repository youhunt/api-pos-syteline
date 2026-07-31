# Evidence — co_mstIup TaxCode Search Hit Was Declaration Only

Date: 31 July 2026
Tenant database: `LENSA_SL_CSI_BAK`

## Tenant-returned source

The returned `co_mstIup` block contained only variable declarations such as:

```sql
@TaxCode1       TaxCodeType,
@OldTaxCode1    TaxCodeType,
@TaxCode2       TaxCodeType,
@OldTaxCode2    TaxCodeType,
@FrtTaxCode1    TaxCodeType,
@OldFrtTaxCode1 TaxCodeType,
@FrtTaxCode2    TaxCodeType,
@OldFrtTaxCode2 TaxCodeType,
@MscTaxCode1    TaxCodeType,
@OldMscTaxCode1 TaxCodeType,
@MscTaxCode2    TaxCodeType,
@OldMscTaxCode2 TaxCodeType
```

It did not include executable tax validation, `MsgAppSp`, `RaiseErrorSp`, or a called validator.

## Interpretation

The previous module search matched a declaration occurrence only. It did not identify the object or predicate that raised the tax-code error.

## Next read-only step

Enumerate every occurrence of `@TaxCode1` in `dbo.co_mstIup`, excluding the declaration area, and capture surrounding executable blocks. Focus on blocks containing `EXEC`, `MsgAppSp`, `RaiseErrorSp`, `taxcode`, or validation predicates.
