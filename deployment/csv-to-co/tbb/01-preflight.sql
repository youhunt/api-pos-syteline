/* =============================================================================
   SMK069 TBB PRE-FLIGHT
   Scope : TRN -> TBB October retry/history delta
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
    SELECT 10 AS sort_group, 1 AS sort_item,
           N'Dependency' AS check_group,
           N'inbound table' AS check_name,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst',N'U') IS NULL
                THEN N'FAIL' ELSE N'PASS' END AS result,
           N'dbo.ue_SMK069_pos_sales_inbound_mst' AS detail

    UNION ALL
    SELECT 10,2,N'Dependency',N'temp table',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst',N'U') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.ue_SMK069_temp_sales_mst'

    UNION ALL
    SELECT 10,3,N'Dependency',N'mapping view',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view',N'V') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.ue_SMK069_pos_sales_inbound_mapping_view'

    UNION ALL
    SELECT 10,4,N'Dependency',N'field map table',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_field_map_mst',N'U') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.ue_SMK069_pos_field_map_mst'

    UNION ALL
    SELECT 10,5,N'Dependency',N'SMK030_UomConvQty2',
           CASE WHEN OBJECT_ID(N'dbo.SMK030_UomConvQty2') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'quantity conversion dependency'

    UNION ALL
    SELECT 10,6,N'Dependency',N'Getumcf',
           CASE WHEN OBJECT_ID(N'dbo.Getumcf') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'U/M conversion dependency'

    UNION ALL
    SELECT 20,1,N'UET',N'itemcust Peak field',
           CASE WHEN COL_LENGTH(N'dbo.itemcust_mst',N'Uf_SMK069_is_peak_season') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'itemcust_mst.Uf_SMK069_is_peak_season'

    UNION ALL
    SELECT 20,2,N'UET',N'itemcust POS U/M field',
           CASE WHEN COL_LENGTH(N'dbo.itemcust_mst',N'Uf_SMK069_pos_um') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'itemcust_mst.Uf_SMK069_pos_um'

    UNION ALL
    SELECT 30,1,N'October Delta',N'history table',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_hist',N'U') IS NULL
                THEN N'INFO' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_hist',N'U') IS NULL
                THEN N'not installed yet - expected before copy'
                ELSE N'already present'
           END

    UNION ALL
    SELECT 30,2,N'October Delta',N'history view',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_history_v',N'V') IS NULL
                THEN N'INFO' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_history_v',N'V') IS NULL
                THEN N'not installed yet - expected before copy'
                ELSE N'already present'
           END

    UNION ALL
    SELECT 40,1,N'Existing Runtime',N'Core Receive SP',
           CASE WHEN OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp',N'P') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'will be replaced by exact verified TRN definition'

    UNION ALL
    SELECT 40,2,N'Existing Runtime',N'Public Receive SP',
           CASE WHEN OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp',N'P') IS NULL
                THEN N'FAIL' ELSE N'PASS' END,
           N'will be replaced by exact verified TRN definition'
) AS x(sort_group,sort_item,check_group,check_name,result,detail)
ORDER BY x.sort_group,x.sort_item
