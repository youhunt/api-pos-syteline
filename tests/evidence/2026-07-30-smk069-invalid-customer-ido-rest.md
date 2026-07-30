# SMK069 Invalid-Customer IDO REST Invocation Evidence

## Date

```text
30 July 2026
```

## Invocation

```text
IDO        : ue_SMK069TempSales
Method     : ue_SMK069ValidateCustomerSp
SiteRef    : DEFAULT
CO Number  : TEST000002
Customer   : TST0002
```

The method was invoked through the Mongoose `InvokeMethod` REST layer with the third parameter left blank as the output placeholder for `Infobar`.

## Observed JSON Response

```json
{
  "Message": null,
  "MessageCode": 0,
  "Parameters": [
    "DEFAULT",
    "TEST000002",
    "Customer TST0002 tidak ditemukan di customer_mst."
  ],
  "ReturnValue": "0"
}
```

## Verification

```text
[VERIFIED] HTTP request reached the Mongoose IDO REST layer
[VERIFIED] ue_SMK069ValidateCustomerSp was callable through the IDO
[VERIFIED] MessageCode = 0
[VERIFIED] ReturnValue = 0
[VERIFIED] parameter 1 returned DEFAULT
[VERIFIED] parameter 2 returned TEST000002
[VERIFIED] parameter 3 returned the customer-not-found Infobar
```

The response confirms that the reusable customer-validation method works through the same Mongoose IDO method invocation layer that can later be used by Postman and controlled API workflows.

This test does not yet represent the final external POS receive API contract. The final architecture still requires a controlled service IDO receive method rather than unrestricted direct writes to the staging entity IDO.

## Result

```text
Invalid-customer stored-procedure test : PASSED
Invalid-customer IDO REST test         : PASSED
Valid-customer validation test         : PENDING
```
