/* =============================================================================
   SMK069 - POS inbound history read model
   Scope : Error Processing -> History tab
   Date  : 12 Oct 2026

   Semantics
   - archived failed attempts come from ue_SMK069_pos_sales_inbound_hist
   - current failed attempt appears as CURRENT_ERROR
   - current successful/transferred attempt appears as SUCCESS
   - attempt number is per SiteRef + source_system + batch_id
   ============================================================================= */

CREATE OR ALTER VIEW dbo.ue_SMK069_pos_sales_inbound_history_v
AS

/* ---------------------------------------------------------------------------
   Archived previous failed attempts
   --------------------------------------------------------------------------- */
SELECT
    CAST(N'H-' + CONVERT(NVARCHAR(30), h.history_id) AS NVARCHAR(50))
        AS history_key,

    h.history_id,
    h.original_inbound_id AS inbound_id,
    h.RowPointer,
    h.SiteRef,
    h.source_system,
    h.batch_id,
    h.row_no,
    h.cust_po,
    h.order_date,
    h.co_num,
    h.co_line,
    h.item,
    h.qty_ordered,
    h.u_m,
    h.whse,
    h.due_date,
    h.inbound_status,
    h.validation_msg,
    h.raw_json,
    h.attempt_no,
    h.archived_date,
    h.archive_reason,
    CAST(0 AS BIT) AS is_current
FROM dbo.ue_SMK069_pos_sales_inbound_hist AS h

UNION ALL

/* ---------------------------------------------------------------------------
   Current attempt.
   E = active/current error.
   T = successfully transferred/current successful attempt.
   --------------------------------------------------------------------------- */
SELECT
    CAST(N'C-' + CONVERT(NVARCHAR(30), i.inbound_id) AS NVARCHAR(50))
        AS history_key,

    CAST(NULL AS BIGINT) AS history_id,
    i.inbound_id,
    i.RowPointer,
    i.SiteRef,
    i.source_system,
    i.batch_id,
    i.row_no,
    i.cust_po,
    i.order_date,
    i.co_num,
    i.co_line,
    i.item,
    i.qty_ordered,
    i.u_m,
    i.whse,
    i.due_date,
    i.inbound_status,
    i.validation_msg,
    i.raw_json,

    ISNULL
    (
        (
            SELECT MAX(h.attempt_no)
            FROM dbo.ue_SMK069_pos_sales_inbound_hist AS h
            WHERE h.SiteRef       = i.SiteRef
              AND h.source_system = i.source_system
              AND h.batch_id      = i.batch_id
        ),
        0
    ) + 1 AS attempt_no,

    COALESCE
    (
        i.transferred_date,
        i.validated_date,
        i.received_date
    ) AS archived_date,

    CAST
    (
        CASE
            WHEN i.inbound_status = N'E' THEN N'CURRENT_ERROR'
            WHEN i.inbound_status = N'T' THEN N'SUCCESS'
            ELSE N'CURRENT'
        END
        AS NVARCHAR(100)
    ) AS archive_reason,

    CAST(1 AS BIT) AS is_current
FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
WHERE i.inbound_status IN (N'E', N'T');
