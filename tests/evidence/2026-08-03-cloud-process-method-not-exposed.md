# Cloud Process Method Not Exposed

Date: 2026-08-03
Tenant runtime result:

```json
{
  "Message": "Method ue_SMK069TempSales.SMK069ProcessCustomerOrderSp not found.",
  "MessageCode": 460,
  "Parameters": null,
  "ReturnValue": null
}
```

Interpretation:

- IDO `ue_SMK069TempSales` is reachable through the Cloud REST API.
- Staging insert and `ue_SMK069ValidateCustomerSp` already work.
- Source order `TEST000002` has reached process status `V`.
- Stored procedure `dbo.SMK069ProcessCustomerOrderSp` is not yet exposed as an IDO method named `SMK069ProcessCustomerOrderSp` on `ue_SMK069TempSales`.

Required tenant metadata action:

1. Add a stored-procedure method to IDO `ue_SMK069TempSales`.
2. Exposed method name: `SMK069ProcessCustomerOrderSp`.
3. Stored procedure: `dbo.SMK069ProcessCustomerOrderSp`.
4. Configure the seven parameters in exact ordinal order:
   - SiteRef, input, SiteType
   - SourceCoNum, input, CoNumType
   - CustSeq, input, CustSeqType
   - ProcessedBy, input, UsernameType
   - CreatedCoNum, output, CoNumType
   - Success, output, ListYesNoType
   - Infobar, output, InfobarType
5. Save, regenerate/resynchronize metadata if required by the tenant, and clear the IDO metadata cache before retesting.

Intended REST retest:

```text
/json/method/ue_SMK069TempSales/SMK069ProcessCustomerOrderSp?parms=DEFAULT,TEST000002,0,,,0,
```
