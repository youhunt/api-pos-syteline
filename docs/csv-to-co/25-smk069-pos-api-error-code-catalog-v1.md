# SMK069 POS API Error Code Catalog v1.0

**Date:** 2 September 2026

## Status

The POS-xxx codes below are the implementation contract for the prepared SP source package.

**Important:** this document must not be treated as tenant-confirmed until the SQL revisions are applied and UAT passes.

## Code groups

- `POS-000` success
- `POS-0xx` request/payload validation
- `POS-1xx` mapping/master validation
- `POS-2xx` order/business validation
- `POS-3xx` Customer Order processing
- `POS-4xx` CSV test/import
- `POS-9xx` configuration/technical

## Catalog

| Code | Name | Meaning |
|---|---|---|
| POS-000 | SUCCESS | Request/order successfully processed |
| POS-001 | INVALID_JSON | Invalid/empty JSON payload |
| POS-002 | CUSTNUM_REQUIRED | custnum is empty |
| POS-003 | ORDER_DATE_INVALID | order_date is empty/invalid |
| POS-004 | CUST_PO_REQUIRED | cust_po is empty |
| POS-005 | WHSE_REQUIRED | whse is empty |
| POS-006 | COLINE_INVALID | coline is empty or <= 0 |
| POS-007 | ITEM_REQUIRED | item is empty |
| POS-008 | QTY_INVALID | qty_ordered is empty or <= 0 |
| POS-009 | UOM_REQUIRED | u_m is empty |
| POS-010 | EXCHANGE_RATE_INVALID | exch_rate <= 0 |
| POS-011 | FIELD_LENGTH_INVALID | payload field exceeds contract length |
| POS-012 | BATCH_ID_REQUIRED | BatchId is empty |
| POS-101 | MAPPING_NOT_FOUND | payload line does not produce a final mapping |
| POS-102 | STORE_NOT_REGISTERED | store/customer mapping unavailable |
| POS-103 | ITEM_NOT_REGISTERED | item/material mapping unavailable |
| POS-104 | UOM_NOT_VALID | U/M invalid for the mapped line |
| POS-105 | PRICE_NOT_FOUND | price unavailable for item/U/M/order date |
| POS-106 | WAREHOUSE_NOT_VALID | warehouse mapping invalid |
| POS-107 | CUSTOMER_SEQUENCE_NOT_FOUND | customer sequence unavailable |
| POS-108 | MAPPING_AMBIGUOUS / QUANTITY_MULTIPLE | historical code; current canonical Receive also uses it for quantity-multiple rejection |
| POS-109 | ITEM_VALIDATION_STATUS_INVALID | at least one mapped item has ValidationStatus=N, so the whole cust_po is rejected |
| POS-201 | DUPLICATE_COLINE | duplicate coline within the same cust_po |
| POS-202 | HEADER_INCONSISTENT | header values inconsistent within one cust_po |
| POS-203 | ORDER_REJECTED | one invalid line rejects the entire cust_po |
| POS-204 | ORDER_ALREADY_EXISTS | order/cust_po already processed or conflicts |
| POS-301 | CO_PROCESS_INVALID | order is not ready for CO processing |
| POS-302 | CO_LINE_CREATE_FAILED | coitem lines not created completely |
| POS-303 | BLANKET_LINE_CREATE_FAILED | blanket lines not created completely |
| POS-304 | EXISTING_CO_CONFLICT | existing CO differs from request |
| POS-305 | CUSTOMER_ENRICHMENT_FAILED | mapped customer cannot be used to create CO |
| POS-306 | CUSTOMER_CURRENCY_NOT_FOUND | default customer currency unavailable |
| POS-401 | CSV_BATCH_NOT_FOUND | CSV batch not found |
| POS-402 | CSV_DETAIL_NOT_FOUND | CSV batch/file/detail missing |
| POS-403 | CSV_HEADER_INVALID | CSV header invalid |
| POS-404 | CSV_ROW_INVALID | CSV row format validation failed |
| POS-405 | CSV_JSON_BUILD_FAILED | JSON could not be built from CSV |
| POS-901 | CONFIGURATION_ERROR | integration/system configuration error |
| POS-902 | TRANSFER_FAILED | valid row failed to transfer to processing temp |
| POS-999 | INTERNAL_ERROR | unclassified internal error |

## Contract rules

- `ue_SMK069_pos_sales_inbound_mapping_view` remains the business source of truth.
- One invalid line rejects the whole `cust_po`.
- A rejected order does not enter processing temp and does not create CO.
- External JSON API returns an invocation failure/non-200 on business rejection.
- Retry of the same failed BatchId returns the same stable business error code/result and must not add a new “already processed” error.
- External consumers should branch on the stable `POS-xxx` code, not on free-text wording.


## Success transport example

For a valid standard IDO invoke, Mongoose returns its normal success envelope:

```json
{
  "Message": null,
  "Success": true,
  "Parameters": [
    "...",
    "[POS-000] Batch DEV4-198 diterima. Row: 1; order(cust_po): 1; valid: 1; error: 0; row masuk temp: 1."
  ],
  "ReturnValue": "0"
}
```

The stable integration code is `POS-000` in the Infobar/output parameter. `Message=null` is normal for a successful standard IDO invocation.
