# Cloud runtime evidence — TEST000002 processed

Date: 2026-08-03
Environment: SyteLine Cloud / Mongoose REST
IDO: `ue_SMK069TempSales`
Source order: `TEST000002`
Created Customer Order: `CO26080001`

## Confirmed runtime result

After invoking `SMK069ProcessCustomerOrderSp`, the staging record was read back through the IDO and returned:

```text
SiteRef         = DEFAULT
co_num          = TEST000002
co_line         = 1
process_status  = P
validation_msg  = NULL
error_msg       = NULL
processed_date  = 2026-08-03 02:46:45.727
processed_by    = BRONZECLEVEROX_TRN_CSI_AIO_0
```

The process method had previously returned:

```text
CreatedCoNum = CO26080001
Success      = 1
ReturnValue  = 0
Infobar      = Customer Order CO26080001 berhasil dibuat dari source order TEST000002.
```

## Conclusion

The Cloud flow is tenant-confirmed through these stages:

```text
REST additem
→ staging status N
→ ue_SMK069ValidateCustomerSp
→ staging status V
→ SMK069ProcessCustomerOrderSp
→ Customer Order number CO26080001 returned
→ staging status P with no validation/error message
```

Header and line existence in the standard Customer Order objects should still be verified separately before marking database-level end-to-end verification complete.
