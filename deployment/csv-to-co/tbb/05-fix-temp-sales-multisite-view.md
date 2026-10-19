# Fix Error Processing primary-grid Site Isolation

**Date:** 19 October 2026  
**Scope:** ue_SMK069_temp_sales_mst / ue_SMK069TempSales / ue_SMK069APISalesErrorProcessing

## Evidence

TBB diagnostic:

~~~text
Active site      = TRN_TBB
Temp rows        = SiteRef=DEFAULT, rows=718
Generated view   = not found
Cross-site       = WARN
~~~

Therefore the Error Processing form is reading the shared physical _mst table
without a site-aware Mongoose view/filter.

## Do not do

~~~text
- do not delete DEFAULT rows
- do not update DEFAULT rows to TRN_TBB
- do not hardcode TRN_TBB in a shared form
- do not change the public Receive SP for this UI defect
~~~

## Preferred Mongoose fix

### 1. SQL Tables

Open SQL Tables and locate:

~~~text
ue_SMK069_temp_sales_mst
~~~

Verify the table is configured as Multi-Site / has a site-splitting column.

Site column:

~~~text
SiteRef
~~~

Do not save destructive table changes until existing keys/indexes are reviewed.

### 2. Application Schema Tables Metadata

Locate the same table and configure:

~~~text
Table Name       = ue_SMK069_temp_sales_mst
View Name        = ue_SMK069_temp_sales
Site Column Name = SiteRef
~~~

The view name follows the standard _mst -> no _mst convention.

### 3. View Management

Open View Management and regenerate the specific view/table.

Expected SQL object after regeneration:

~~~text
dbo.ue_SMK069_temp_sales
~~~

### 4. Verify generated view before touching the IDO

From a TBB session:

~~~sql
SELECT TOP (20)
    SiteRef,
    co_num,
    cust_po,
    co_line,
    item,
    process_status
FROM dbo.ue_SMK069_temp_sales
ORDER BY order_date DESC, co_num, co_line
~~~

Expected in TRN_TBB:

~~~text
no SiteRef=DEFAULT rows
only TRN_TBB rows when TBB activity exists
possibly 0 rows before first TBB transaction
~~~

### 5. IDO source

Open:

~~~text
ue_SMK069TempSales
~~~

Verify/resynchronize its primary source so the collection uses the generated
site-aware view rather than reading the shared _mst rows directly.

Do not remove or recreate existing stored-procedure methods.

Especially preserve:

~~~text
SMK069ReceivePosSalesJsonSp -> Transactional=False
SMK069ValidateFilteredStagingSp
SMK069ProcessCustomerOrderSp
~~~

### 6. Form

The form can remain logically unchanged:

~~~text
ue_SMK069APISalesErrorProcessing
Primary collection = ue_SMK069TempSales
~~~

Once the IDO is site-aware, the existing date/CO filters continue to work and
the form should automatically show only the active site's rows.

### 7. Acceptance

In TBB / ActiveSite=TRN_TBB:

~~~text
[ ] Error Processing shows no DEFAULT rows
[ ] History shows no DEFAULT rows
[ ] TBB Postman request creates SiteRef=TRN_TBB rows
[ ] Refresh shows new TBB rows
[ ] Validate only processes TRN_TBB
[ ] Process/Reprocess only processes TRN_TBB
~~~

In DEFAULT/TDN:

~~~text
[ ] existing DEFAULT rows remain visible there
[ ] no TRN_TBB rows leak into DEFAULT/TDN
~~~

## Rollback

Before changing Mongoose metadata, export/backup:

~~~text
SQL Tables metadata for ue_SMK069_temp_sales_mst
Application Schema Tables Metadata row
ue_SMK069TempSales IDO
ue_SMK069APISalesErrorProcessing form
~~~

If generated-view/IDO resync causes an issue, restore the metadata/IDO export.
Transactional table rows do not need to be changed for this fix.