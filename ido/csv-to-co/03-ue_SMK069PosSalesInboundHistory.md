# ue_SMK069PosSalesInboundHistory

**Status:** TRN working design documented; exact Object Studio XML export still required for PRD parity.

## Purpose

Read-only IDO for the **History** tab on:

~~~text
ue_SMK069APISalesErrorProcessing
SMK API SALES ERROR PROCESSING
~~~

SQL source:

~~~text
dbo.ue_SMK069_pos_sales_inbound_history_v
~~~

The view combines:

~~~text
archived failed attempts -> ue_SMK069_pos_sales_inbound_hist
current error rows       -> ue_SMK069_pos_sales_inbound_mst / CURRENT_ERROR
current transferred rows -> ue_SMK069_pos_sales_inbound_mst / SUCCESS
~~~

## IDO contract

IDO name:

~~~text
ue_SMK069PosSalesInboundHistory
~~~

Recommended behavior:

~~~text
Read Only = True
Insert    = disabled
Update    = disabled
Delete    = disabled
~~~

Logical unique row key:

~~~text
HistoryKey
~~~

The view generates:

~~~text
H-<history_id>  = archived row
C-<inbound_id>  = current row
~~~

Do not use RowPointer as the History collection identity because archived and
current records represent different lifecycle records.

## Required properties

Map the SQL columns from the view to these IDO properties:

| IDO property | SQL column | Purpose |
|---|---|---|
| HistoryKey | history_key | unique collection key |
| HistoryId | history_id | archive identity |
| InboundId | inbound_id | original/current inbound identity |
| RowPointer | RowPointer | source row pointer |
| SiteRef | SiteRef | SyteLine site |
| SourceSystem | source_system | POS/source identifier |
| BatchId | batch_id | request batch |
| RowNo | row_no | source row number |
| CustPo | cust_po | business PO |
| OrderDate | order_date | order date |
| CoNum | co_num | current/created CO reference |
| CoLine | co_line | line |
| Item | item | source item |
| QtyOrdered | qty_ordered | source quantity |
| UM | u_m | source U/M |
| Whse | whse | warehouse |
| DueDate | due_date | due date |
| InboundStatus | inbound_status | E/T |
| ValidationMsg | validation_msg | full validation message |
| RawJson | raw_json | original raw payload |
| AttemptNo | attempt_no | retry attempt |
| ArchivedDate | archived_date | history/current event timestamp |
| ArchiveReason | archive_reason | CURRENT_ERROR / RETRY_SAME_BATCH / SUCCESS |
| IsCurrent | is_current | 1=current, 0=archived |

## Form collection contract

The verified TRN form uses this secondary collection:

~~~text
OBJECT2(
  ue_SMK069PosSalesInboundHistory(
    CA(IGVR)
    OBJNAME(History)
    ORDERBY(ArchivedDate DESC, AttemptNo DESC, RowNo)
    LOCKMODE(Row)
  )
)
~~~

The form binds the History grid through:

~~~text
object2
~~~

and refreshes it through:

~~~text
RefreshHistory
StdFormInitCompleted -> RefreshHistory()
StdFormRefresh       -> RefreshHistory()
~~~

## Important note about ValidationMsg

Do not shorten ValidationMsg in the IDO merely because the custom SQL Query
Execution form truncates long values. The actual IDO/grid path in TRN works with
the full validation message.

## PRD migration rule

Preferred path:

~~~text
1. Export exact working TRN IDO from Object Studio
2. Save export in repository
3. Import the same verified IDO into PRD
4. Resynchronize metadata if required
5. Open form and verify History collection loads
~~~

Do not manually invent a PROD-only IDO definition when the working TRN export is
available.

## Acceptance

~~~text
[ ] IDO opens without metadata error
[ ] HistoryKey exposed and unique
[ ] ValidationMsg full text available
[ ] current E displays as CURRENT_ERROR
[ ] archived attempt displays as RETRY_SAME_BATCH
[ ] current T displays as SUCCESS
[ ] form StdFormRefresh reloads object2
~~~
