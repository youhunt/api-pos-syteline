/* =============================================================================
   SMK069 PROD PRE-FLIGHT
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-28
   Mode  : READ ONLY
   Tool  : Query Select
   Rule  : EXACTLY ONE SELECT statement. No DECLARE, SET, IF, THROW, temp tables,
           GO, or multiple result sets.

   PASS gate:
   - every row in the result must be PASS or INFO
   - any FAIL means do NOT run 02-deploy-canonical-runtime.sql yet
   - the mapping view itself is optional at preflight because 02 creates/alters it
   ============================================================================= */

SELECT
    q.check_group,
    q.check_name,
    q.result,
    q.detail
FROM
(
    /* ----------------------------------------------------------------------
       1. Required custom tables
       ---------------------------------------------------------------------- */
    SELECT 10 AS sort_group, 1 AS sort_item,
           N'Required Object' AS check_group,
           N'dbo.ue_SMK069_pos_sales_inbound_mst' AS check_name,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst',N'U') IS NULL THEN N'FAIL' ELSE N'PASS' END AS result,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst',N'U') IS NULL THEN N'table tidak ditemukan' ELSE N'OK' END AS detail

    UNION ALL
    SELECT 10,2,N'Required Object',N'dbo.ue_SMK069_temp_sales_mst',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst',N'U') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst',N'U') IS NULL THEN N'table tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 10,3,N'Required Object',N'dbo.ue_SMK069_pos_field_map_mst',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_field_map_mst',N'U') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_field_map_mst',N'U') IS NULL THEN N'field-map table tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 10,4,N'Required Object',N'dbo.ue_SMK069_pos_csv_batch_mst',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst',N'U') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst',N'U') IS NULL THEN N'CSV batch table tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 10,5,N'Required Object',N'dbo.ue_SMK069_pos_csv_upload_mst',
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst',N'U') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst',N'U') IS NULL THEN N'CSV upload detail table tidak ditemukan' ELSE N'OK' END

    /* ----------------------------------------------------------------------
       2. Required helper/runtime prerequisites
       ---------------------------------------------------------------------- */
    UNION ALL
    SELECT 20,1,N'Runtime Prerequisite',N'dbo.SMK030_UomConvQty2',
           CASE WHEN OBJECT_ID(N'dbo.SMK030_UomConvQty2') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.SMK030_UomConvQty2') IS NULL THEN N'quantity conversion function tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 20,2,N'Runtime Prerequisite',N'dbo.Getumcf',
           CASE WHEN OBJECT_ID(N'dbo.Getumcf') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.Getumcf') IS NULL THEN N'U/M conversion function tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 20,3,N'Runtime Prerequisite',N'dbo.SetSiteSp',
           CASE WHEN OBJECT_ID(N'dbo.SetSiteSp',N'P') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.SetSiteSp',N'P') IS NULL THEN N'standard site context procedure tidak ditemukan' ELSE N'OK' END

    /* ----------------------------------------------------------------------
       2b. Form / IDO helper stored procedures imported from DEV metadata
       ---------------------------------------------------------------------- */
    UNION ALL
    SELECT 25,1,N'Form/IDO Runtime Dependency',N'dbo.SMK069InitializeCsvTestBatchSp',
           CASE WHEN OBJECT_ID(N'dbo.SMK069InitializeCsvTestBatchSp',N'P') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.SMK069InitializeCsvTestBatchSp',N'P') IS NULL THEN N'New Batch helper tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 25,2,N'Form/IDO Runtime Dependency',N'dbo.SMK069ConfirmCsvUploadSp',
           CASE WHEN OBJECT_ID(N'dbo.SMK069ConfirmCsvUploadSp',N'P') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.SMK069ConfirmCsvUploadSp',N'P') IS NULL THEN N'CSV upload confirmation helper tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 25,3,N'Form/IDO Runtime Dependency',N'dbo.SMK069ValidateFilteredStagingSp',
           CASE WHEN OBJECT_ID(N'dbo.SMK069ValidateFilteredStagingSp',N'P') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN OBJECT_ID(N'dbo.SMK069ValidateFilteredStagingSp',N'P') IS NULL THEN N'Error Processing Validate helper tidak ditemukan' ELSE N'OK' END

    /* ----------------------------------------------------------------------
       3. Inbound required columns
       ---------------------------------------------------------------------- */
    UNION ALL
    SELECT
        30,
        e.seq,
        N'Inbound Column',
        e.column_name,
        CASE WHEN c.column_id IS NULL THEN N'FAIL' ELSE N'PASS' END,
        CASE WHEN c.column_id IS NULL THEN N'required inbound column tidak ditemukan' ELSE N'OK' END
    FROM
    (
        VALUES
          (1,N'inbound_id'),(2,N'source_system'),(3,N'batch_id'),(4,N'row_no'),
          (5,N'raw_json'),(6,N'SiteRef'),(7,N'cust_num'),(8,N'order_date'),
          (9,N'co_num'),(10,N'co_line'),(11,N'item'),(12,N'qty_ordered'),
          (13,N'unit_price'),(14,N'whse'),(15,N'due_date'),(16,N'u_m'),
          (17,N'terms_code'),(18,N'tax_code1'),(19,N'exch_rate'),
          (20,N'inbound_status'),(21,N'validation_msg'),(22,N'received_date'),
          (23,N'validated_date'),(24,N'transferred_date'),(25,N'cust_po'),
          (26,N'is_peak_season')
    ) AS e(seq,column_name)
    LEFT JOIN sys.columns AS c
      ON c.object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst')
     AND c.name = e.column_name

    /* ----------------------------------------------------------------------
       4. Temp required columns
       ---------------------------------------------------------------------- */
    UNION ALL
    SELECT
        40,
        e.seq,
        N'Temp Column',
        e.column_name,
        CASE WHEN c.column_id IS NULL THEN N'FAIL' ELSE N'PASS' END,
        CASE WHEN c.column_id IS NULL THEN N'required temp column tidak ditemukan' ELSE N'OK' END
    FROM
    (
        VALUES
          (1,N'SiteRef'),(2,N'cust_num'),(3,N'order_date'),(4,N'terms_code'),
          (5,N'co_num'),(6,N'cust_po'),(7,N'co_line'),(8,N'unit_price'),
          (9,N'tax_code1'),(10,N'exch_rate'),(11,N'whse'),(12,N'item'),
          (13,N'qty_ordered'),(14,N'due_date'),(15,N'u_m'),
          (16,N'is_peak_season'),(17,N'process_status'),(18,N'validation_msg'),
          (19,N'error_msg'),(20,N'retry_count'),(21,N'processed_date'),
          (22,N'processed_by'),(23,N'created_co_num')
    ) AS e(seq,column_name)
    LEFT JOIN sys.columns AS c
      ON c.object_id = OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst')
     AND c.name = e.column_name

    /* ----------------------------------------------------------------------
       5. CSV upload required columns
       ---------------------------------------------------------------------- */
    UNION ALL
    SELECT
        50,
        e.seq,
        N'CSV Upload Column',
        e.column_name,
        CASE WHEN c.column_id IS NULL THEN N'FAIL' ELSE N'PASS' END,
        CASE WHEN c.column_id IS NULL THEN N'required CSV detail column tidak ditemukan' ELSE N'OK' END
    FROM
    (
        VALUES
          (1,N'SiteRef'),(2,N'batch_id'),(3,N'row_no'),(4,N'custnum'),
          (5,N'order_date'),(6,N'cust_po'),(7,N'whse'),(8,N'coline'),
          (9,N'item'),(10,N'qty_ordered'),(11,N'u_m'),(12,N'due_date'),
          (13,N'terms_code'),(14,N'tax_code1'),(15,N'exch_rate'),
          (16,N'is_peak_season'),(17,N'upload_status'),(18,N'result_message')
    ) AS e(seq,column_name)
    LEFT JOIN sys.columns AS c
      ON c.object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst')
     AND c.name = e.column_name

    /* ----------------------------------------------------------------------
       6. UET fields on itemcust_mst
       ---------------------------------------------------------------------- */
    UNION ALL
    SELECT 60,1,N'UET Field',N'itemcust_mst.Uf_SMK069_is_peak_season',
           CASE WHEN COL_LENGTH(N'dbo.itemcust_mst',N'Uf_SMK069_is_peak_season') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN COL_LENGTH(N'dbo.itemcust_mst',N'Uf_SMK069_is_peak_season') IS NULL THEN N'UET field belum tersedia' ELSE N'OK' END

    UNION ALL
    SELECT 60,2,N'UET Field',N'itemcust_mst.Uf_SMK069_pos_um',
           CASE WHEN COL_LENGTH(N'dbo.itemcust_mst',N'Uf_SMK069_pos_um') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN COL_LENGTH(N'dbo.itemcust_mst',N'Uf_SMK069_pos_um') IS NULL THEN N'UET field belum tersedia' ELSE N'OK' END

    /* ----------------------------------------------------------------------
       7. Target SyteLine columns used by final processor
       ---------------------------------------------------------------------- */
    UNION ALL
    SELECT 70,1,N'Target Column',N'co_mst.consolidate',
           CASE WHEN COL_LENGTH(N'dbo.co_mst',N'consolidate') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN COL_LENGTH(N'dbo.co_mst',N'consolidate') IS NULL THEN N'column tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 70,2,N'Target Column',N'coitem_mst.consolidate',
           CASE WHEN COL_LENGTH(N'dbo.coitem_mst',N'consolidate') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN COL_LENGTH(N'dbo.coitem_mst',N'consolidate') IS NULL THEN N'column tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 70,25,N'Target Column',N'coitem_mst.co_release',
           CASE WHEN COL_LENGTH(N'dbo.coitem_mst',N'co_release') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN COL_LENGTH(N'dbo.coitem_mst',N'co_release') IS NULL THEN N'column tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 70,3,N'Target Column',N'coitem_mst.release_date',
           CASE WHEN COL_LENGTH(N'dbo.coitem_mst',N'release_date') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN COL_LENGTH(N'dbo.coitem_mst',N'release_date') IS NULL THEN N'column tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 70,4,N'Target Column',N'co_bln_mst.stat',
           CASE WHEN COL_LENGTH(N'dbo.co_bln_mst',N'stat') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN COL_LENGTH(N'dbo.co_bln_mst',N'stat') IS NULL THEN N'column tidak ditemukan' ELSE N'OK' END

    UNION ALL
    SELECT 70,5,N'Target Column',N'co_bln_mst.allow_on_pick_list',
           CASE WHEN COL_LENGTH(N'dbo.co_bln_mst',N'allow_on_pick_list') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           CASE WHEN COL_LENGTH(N'dbo.co_bln_mst',N'allow_on_pick_list') IS NULL THEN N'column tidak ditemukan' ELSE N'OK' END

    /* ----------------------------------------------------------------------
       8. Mapping view is optional before runtime deployment
       ---------------------------------------------------------------------- */
    UNION ALL
    SELECT 80,1,N'Optional Before Deploy',N'dbo.ue_SMK069_pos_sales_inbound_mapping_view',
           N'INFO',
           CASE
             WHEN OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view',N'V') IS NULL
               THEN N'belum ada; akan dibuat oleh 02-deploy-canonical-runtime.sql'
             ELSE N'sudah ada; 02 akan CREATE OR ALTER ke versi final'
           END
) AS q(sort_group,sort_item,check_group,check_name,result,detail)
ORDER BY q.sort_group,q.sort_item;