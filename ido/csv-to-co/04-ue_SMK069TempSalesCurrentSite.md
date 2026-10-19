# ue_SMK069TempSalesCurrentSite

**Purpose:** read-only, site-isolated primary collection for
`ue_SMK069APISalesErrorProcessing`.

## Why this IDO exists

The generated Mongoose multi-site view `dbo.ue_SMK069_temp_sales` correctly
hides the physical `SiteRef` partition column. That is useful for generic
site-aware data access, but the existing Error Processing form currently passes
`P(SiteRef)` to Validate and Process/Reprocess methods.

Therefore do **not** repoint the existing service IDO `ue_SMK069TempSales`
directly to a source that drops SiteRef.

Use a dedicated read-only form IDO instead.

## SQL source

~~~text
dbo.ue_SMK069_temp_sales_current_site_v
~~~

The view filters the physical staging table by the active Mongoose site from
`CONTEXT_INFO()` and still exposes the original `SiteRef` column.

## IDO

~~~text
Name      : ue_SMK069TempSalesCurrentSite
Read only : Yes
Source    : dbo.ue_SMK069_temp_sales_current_site_v
Key       : RowPointer
~~~

Expose the same display properties used by the existing form, including:

~~~text
SiteRef
order_date
co_num
co_line
cust_num
cust_po
item
qty_ordered
u_m
unit_price
whse
due_date
terms_code
process_status
validation_msg
error_msg
created_co_num
is_peak_season
is_urgent
urgent_remark
RowPointer
~~~

## Form change

Change only the primary collection source:

~~~text
FROM: ue_SMK069TempSales
TO  : ue_SMK069TempSalesCurrentSite
~~~

Keep method calls exactly as they are:

~~~text
ue_SMK069TempSales.SMK069ValidateFilteredStagingSp
ue_SMK069TempSales.SMK069ProcessCustomerOrderSp
~~~

This preserves the service/API IDO and its method metadata while making the
form grid site-safe.

## Acceptance

In TBB / ActiveSite=TRN_TBB:

~~~text
Error Processing grid -> no DEFAULT rows
History grid          -> no DEFAULT rows
selected SiteRef      -> TRN_TBB
Validate              -> still works
Process/Reprocess     -> still works
~~~