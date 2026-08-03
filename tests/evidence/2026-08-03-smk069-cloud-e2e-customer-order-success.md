# SMK069 Cloud End-to-End Customer Order Success

## Date

2026-08-03

## Environment

Infor SyteLine / Mongoose Cloud tenant, site `DEFAULT`.

## Source Staging Record

```text
SiteRef       : DEFAULT
co_num        : TEST000002
co_line       : 1
cust_num      : C000001
item          : AA00001
qty_ordered   : 1
u_m           : KG
unit_price    : 10000
tax_code1     : PPN11%
whse          : MAIN
terms_code    : CBD
```

## REST Staging Insert

`POST /json/ue_SMK069TempSales/additem`

Result:

```json
{
  "Message": "Insert succeeded",
  "MessageCode": 200
}
```

A subsequent Advanced LoadCollection returned the inserted row with `process_status = N`.

## Customer Validation

Endpoint:

```text
/json/method/ue_SMK069TempSales/ue_SMK069ValidateCustomerSp?parms=DEFAULT,TEST000002,
```

Result:

```text
ReturnValue   : 0
Infobar       : empty
process_status: V
error_msg     : null
```

## Customer Order Processing

Endpoint:

```text
/json/method/ue_SMK069TempSales/SMK069ProcessCustomerOrderSp?parms=DEFAULT,TEST000002,0,,,0,
```

Result:

```text
ReturnValue  : 0
CreatedCoNum : CO26080001
Success      : 1
Infobar      : Customer Order CO26080001 berhasil dibuat dari source order TEST000002.
```

## Staging Final State

```text
process_status : P
validation_msg : null
error_msg      : null
processed_date : 2026-08-03 02:46:45.727 tenant response format
processed_by   : BRONZECLEVEROX_TRN_CSI_AIO_0
```

## Standard Customer Order Header Verification

IDO: `SLCos`

```text
CoNum      : CO26080001
CustNum    : C000001
CustPo     : TEST000002
OrderDate  : 2026-08-03
Whse       : MAIN
TermsCode  : CBD
TaxCode1   : PPN11%
Stat       : P
Price      : 11100.00000000
```

The standard Customer Order header IDO used for verification does not expose a usable `SiteRef` property in this tenant query, so `SiteRef` was omitted from the final header verification request.

## Standard Customer Order Line Verification

IDO: `SLCoitems`

```text
CoNum       : CO26080001
CoLine      : 1
Item        : AA00001
QtyOrdered  : 1.00000000
UM          : KG
Price       : 10000.00000000
Whse        : MAIN
SiteRef     : null in the IDO response
```

`SiteRef = null` in the `SLCoitems` IDO response is treated as an IDO property exposure/mapping observation, not proof that the physical `coitem_mst.site_ref` column is null. The row was created and retrieved successfully in the active Cloud site context.

## Price Observation

```text
Line net price       : 10000
Header returned price: 11100
Difference           : 1100 (11%)
Tax code             : PPN11%
```

The result is numerically consistent with 11% tax being added to the line net amount. Functional confirmation is still required on whether the expected Customer Order header total should be net (`10000`) or tax-inclusive (`11100`).

## Conclusion

The following Cloud flow is tenant-confirmed:

```text
REST additem
→ staging N
→ customer validation
→ staging V
→ SMK069ProcessCustomerOrderSp
→ Customer Order CO26080001 header created
→ Customer Order line 1 created
→ staging P
```

This is the first confirmed end-to-end successful Customer Order creation for the SMK069 flow in the Cloud tenant.
