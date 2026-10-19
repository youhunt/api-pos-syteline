/* =============================================================================
   SMK069 TBB - CREATE SITE-ISOLATED ERROR PROCESSING VIEW
   Date  : 19 Oct 2026
   Scope : ue_SMK069APISalesErrorProcessing primary grid
   Mode  : Apply Database compatible

   No transactional rows are modified.
   ============================================================================= */

CREATE OR ALTER VIEW dbo.ue_SMK069_temp_sales_current_site_v
AS
SELECT
    t.CreatedBy,
    t.UpdatedBy,
    t.CreateDate,
    t.RecordDate,
    t.RowPointer,
    t.NoteExistsFlag,
    t.InWorkflow,
    t.SiteRef,
    t.cust_num,
    t.order_date,
    t.terms_code,
    t.co_num,
    t.co_line,
    t.unit_price,
    t.tax_code1,
    t.exch_rate,
    t.whse,
    t.item,
    t.qty_ordered,
    t.due_date,
    t.u_m,
    t.process_status,
    t.validation_msg,
    t.error_msg,
    t.retry_count,
    t.processed_date,
    t.processed_by,
    t.created_co_num,
    t.cust_po,
    t.is_peak_season,
    t.is_urgent,
    t.urgent_remark
FROM dbo.ue_SMK069_temp_sales_mst AS t
WHERE RTRIM(CONVERT(NVARCHAR(8), t.SiteRef)) =
      RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
