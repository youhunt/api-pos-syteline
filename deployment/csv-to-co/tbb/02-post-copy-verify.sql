/* =============================================================================
   SMK069 TBB POST-COPY VERIFY
   Scope : October retry/history delta
   Mode  : READ ONLY / Query Select
   Rule  : one SELECT statement
   ============================================================================= */

SELECT
    x.check_group,
    x.check_name,
    x.result,
    x.detail
FROM
(
    SELECT 10 AS sort_group,1 AS sort_item,
           N'History Object' AS check_group,
           N'history table' AS check_name,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_hist',N'U') IS NULL
                THEN N'FAIL' ELSE N'PASS' END AS result,
           N'dbo.ue_SMK069_pos_sales_inbound_hist' AS detail

    UNION ALL
    SELECT 10,2,N'History Object',N'history view',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_history_v',N'V') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.ue_SMK069_pos_sales_inbound_history_v'

    UNION ALL
    SELECT 20,1,N'Runtime Marker',N'same-Batch failed retry',
           CASE WHEN CHARINDEX(
                    N'RETRY_SAME_BATCH',
                    COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')),N'')
                ) > 0
                 AND CHARINDEX(
                    N'@RetryFailedBatch',
                    COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')),N'')
                ) > 0
                THEN N'PASS' ELSE N'FAIL' END,
           N'Core must contain verified October same-Batch retry logic'

    UNION ALL
    SELECT 20,2,N'Runtime Marker',N'friendly POS-108',
           CASE WHEN CHARINDEX(
                    N'qty_hasil_konversi',
                    COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')),N'')
                ) > 0
                 AND CHARINDEX(
                    N'Quantity tidak sesuai kelipatan U/M',
                    COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')),N'')
                ) > 0
                THEN N'PASS' ELSE N'FAIL' END,
           N'Public API should expose business POS-108 reason'

    UNION ALL
    SELECT 30,1,N'History View',N'history_key',
           CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_history_v',N'history_key') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'History IDO key'

    UNION ALL
    SELECT 30,2,N'History View',N'attempt_no',
           CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_history_v',N'attempt_no') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'Retry attempt'

    UNION ALL
    SELECT 30,3,N'History View',N'archive_reason',
           CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_history_v',N'archive_reason') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'CURRENT_ERROR / RETRY_SAME_BATCH / SUCCESS'

    UNION ALL
    SELECT 30,4,N'History View',N'is_current',
           CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_history_v',N'is_current') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'current vs archived row flag'

    UNION ALL
    SELECT 30,5,N'History View',N'active SiteRef filter',
           CASE WHEN CHARINDEX(
                    N'CONTEXT_INFO',
                    COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_history_v')),N'')
                ) > 0
                 AND CHARINDEX(
                    N'SiteRef',
                    COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_history_v')),N'')
                ) > 0
                THEN N'PASS' ELSE N'FAIL' END,
           N'History view active SiteRef filter'

    UNION ALL
    SELECT 40,1,N'Data Safety',N'history rows before UAT',
           N'INFO',
           N'History table may be empty before first TBB retry; do not copy TRN history data'
) AS x(sort_group,sort_item,check_group,check_name,result,detail)
ORDER BY x.sort_group,x.sort_item
