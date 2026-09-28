/* =============================================================================
   SMK069 PROD POST-DEPLOY VERIFY
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-28
   Mode  : READ ONLY
   Tool  : Query Select
   Rule  : EXACTLY ONE SELECT statement. No DECLARE, no SET, no temp tables,
           no GO, no multiple result sets.
   ============================================================================= */

SELECT
    q.check_group,
    q.check_name,
    q.result,
    q.detail
FROM
(
    /* ----------------------------------------------------------------------
       1. Required runtime objects
       ---------------------------------------------------------------------- */
    SELECT
        10 AS sort_group,
        x.seq AS sort_item,
        N'Runtime Object' AS check_group,
        x.name AS check_name,
        CASE WHEN o.object_id IS NULL THEN N'FAIL' ELSE N'PASS' END AS result,
        CASE
            WHEN o.object_id IS NULL THEN N'MISSING'
            ELSE o.type_desc + N' | modified='
                 + CONVERT(NVARCHAR(30), o.modify_date, 126)
        END AS detail
    FROM
    (
        VALUES
          (1,N'SMK069CsvSplitLine'),
          (2,N'SMK069ImportCsvFileSp'),
          (3,N'SMK069ValidateCustomerSp'),
          (4,N'SMK069ProcessCustomerOrderSp'),
          (5,N'SMK069ProcessBatchCustomerOrdersSp'),
          (6,N'SMK069ReceivePosSalesJsonCoreSp'),
          (7,N'SMK069ReceivePosSalesJsonSp'),
          (8,N'SMK069RunCsvTestBatchSp')
    ) AS x(seq,name)
    LEFT JOIN sys.objects AS o
      ON o.schema_id = SCHEMA_ID(N'dbo')
     AND o.name = x.name

    UNION ALL

    /* ----------------------------------------------------------------------
       2. Final-source behavior markers
       ---------------------------------------------------------------------- */
    SELECT 20, 1, N'Runtime Marker', N'Core Peak before mapping',
           CASE WHEN CHARINDEX(
               N'Peak Season MUST be persisted before #MapView',
               COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')), N'')
           ) > 0 THEN N'PASS' ELSE N'FAIL' END,
           N'Core must persist Peak before materializing mapping view'

    UNION ALL
    SELECT 20, 2, N'Runtime Marker', N'Public Receive POS-204 reused-batch fallback',
           CASE WHEN CHARINDEX(
               N'PATCH-34: synthesize POS-204 from payload CustPO',
               COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')), N'')
           ) > 0 THEN N'PASS' ELSE N'FAIL' END,
           N'Cross-batch/reused-batch duplicate CustPO protection'

    UNION ALL
    SELECT 20, 3, N'Runtime Marker', N'Public Receive ValidationStatus gate',
           CASE WHEN CHARINDEX(
               N'ValidationStatus',
               COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')), N'')
           ) > 0 THEN N'PASS' ELSE N'FAIL' END,
           N'ValidationStatus=N must reject the atomic CustPO'

    UNION ALL
    SELECT 20, 4, N'Runtime Marker', N'Per-order Blanket line insert',
           CASE WHEN CHARINDEX(
               N'INSERT INTO dbo.co_bln_mst',
               COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp')), N'')
           ) > 0 THEN N'PASS' ELSE N'FAIL' END,
           N'Blanket line creation'

    UNION ALL
    SELECT 20, 5, N'Runtime Marker', N'Per-order created_co_num persistence',
           CASE WHEN CHARINDEX(
               N'created_co_num',
               COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp')), N'')
           ) > 0 THEN N'PASS' ELSE N'FAIL' END,
           N'Actual SyteLine CO traceability'

    UNION ALL
    SELECT 20, 6, N'Runtime Marker', N'Batch POS-302 no silent success',
           CASE WHEN CHARINDEX(
               N'[POS-302]',
               COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessBatchCustomerOrdersSp')), N'')
           ) > 0 THEN N'PASS' ELSE N'FAIL' END,
           N'No-mapping batch must not silently succeed'

    UNION ALL
    SELECT 20, 7, N'Runtime Marker', N'CSV runner Peak Season',
           CASE WHEN CHARINDEX(
               N'is_peak_season',
               COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp')), N'')
           ) > 0 THEN N'PASS' ELSE N'FAIL' END,
           N'CSV runner forwards Peak flag'

    UNION ALL
    SELECT 20, 8, N'Runtime Marker', N'CSV parser Peak alias',
           CASE WHEN CHARINDEX(
               N'is_peak_seson',
               COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ImportCsvFileSp')), N'')
           ) > 0 THEN N'PASS' ELSE N'FAIL' END,
           N'CSV parser retains accepted legacy Peak alias'

    UNION ALL

    /* ----------------------------------------------------------------------
       3. Public Receive SQL parameter contract
       ---------------------------------------------------------------------- */
    SELECT
        30,
        e.parameter_id,
        N'Public Receive Parameter',
        CONVERT(NVARCHAR(10), e.parameter_id) + N' ' + e.parameter_name,
        CASE
            WHEN p.parameter_id IS NULL THEN N'FAIL'
            WHEN p.name <> e.parameter_name THEN N'FAIL'
            WHEN p.is_output <> e.is_output THEN N'FAIL'
            ELSE N'PASS'
        END,
        N'actual=' + COALESCE(p.name,N'<missing>')
        + N' | type=' + COALESCE(TYPE_NAME(p.user_type_id),N'<missing>')
        + N' | max_length=' + COALESCE(CONVERT(NVARCHAR(20),p.max_length),N'<null>')
        + N' | output=' + COALESCE(CONVERT(NVARCHAR(1),p.is_output),N'<null>')
    FROM
    (
        VALUES
          (1,N'@SourceSystem',CAST(0 AS bit)),
          (2,N'@BatchId',CAST(0 AS bit)),
          (3,N'@PayloadJson',CAST(0 AS bit)),
          (4,N'@ReceivedBy',CAST(0 AS bit)),
          (5,N'@ReceivedRows',CAST(1 AS bit)),
          (6,N'@TotalOrders',CAST(1 AS bit)),
          (7,N'@ValidOrders',CAST(1 AS bit)),
          (8,N'@ErrorOrders',CAST(1 AS bit)),
          (9,N'@TransferredRows',CAST(1 AS bit)),
          (10,N'@Infobar',CAST(1 AS bit)),
          (11,N'@ProcessedOrders',CAST(1 AS bit)),
          (12,N'@ProcessErrors',CAST(1 AS bit)),
          (13,N'@CreatedCoNums',CAST(1 AS bit)),
          (14,N'@ThrowOnBusinessError',CAST(0 AS bit))
    ) AS e(parameter_id,parameter_name,is_output)
    LEFT JOIN sys.parameters AS p
      ON p.object_id = OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')
     AND p.parameter_id = e.parameter_id

    UNION ALL

    /* ----------------------------------------------------------------------
       4. Mapping view contract
       ---------------------------------------------------------------------- */
    SELECT
        40,
        e.column_id,
        N'Mapping View Column',
        e.column_name,
        CASE WHEN c.column_id IS NULL THEN N'FAIL' ELSE N'PASS' END,
        CASE
            WHEN c.column_id IS NULL THEN N'MISSING'
            ELSE N'type=' + TYPE_NAME(c.user_type_id)
                 + N' | max_length=' + CONVERT(NVARCHAR(20),c.max_length)
                 + N' | precision=' + CONVERT(NVARCHAR(20),c.precision)
                 + N' | scale=' + CONVERT(NVARCHAR(20),c.scale)
        END
    FROM
    (
        VALUES
          (1,N'inbound_id'),(2,N'source_system'),(3,N'batch_id'),(4,N'row_no'),
          (5,N'raw_json'),(6,N'SiteRef'),(7,N'cust_num'),(8,N'cust_seq'),
          (9,N'cust_po'),(10,N'order_date'),(11,N'co_num'),(12,N'co_line'),
          (13,N'item'),(14,N'qty_ordered'),(15,N'unit_price'),(16,N'whse'),
          (17,N'due_date'),(18,N'u_m'),(19,N'terms_code'),(20,N'tax_code1'),
          (21,N'exch_rate'),(22,N'inbound_status'),(23,N'validation_msg'),
          (24,N'received_date'),(25,N'validated_date'),(26,N'transferred_date'),
          (27,N'created_by'),(28,N'updated_by'),(29,N'is_peak_season'),
          (30,N'ValidationStatus')
    ) AS e(column_id,column_name)
    LEFT JOIN sys.columns AS c
      ON c.object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')
     AND c.name = e.column_name

    UNION ALL

    /* ----------------------------------------------------------------------
       5. Peak/UET physical fields
       ---------------------------------------------------------------------- */
    SELECT 50, 1, N'Physical Field', N'inbound.is_peak_season',
           CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst',N'is_peak_season') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.ue_SMK069_pos_sales_inbound_mst.is_peak_season'
    UNION ALL
    SELECT 50, 2, N'Physical Field', N'temp.is_peak_season',
           CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst',N'is_peak_season') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.ue_SMK069_temp_sales_mst.is_peak_season'
    UNION ALL
    SELECT 50, 3, N'Physical Field', N'csv_upload.is_peak_season',
           CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst',N'is_peak_season') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.ue_SMK069_pos_csv_upload_mst.is_peak_season'
    UNION ALL
    SELECT 50, 4, N'Physical Field', N'itemcust.Uf_SMK069_is_peak_season',
           CASE WHEN COL_LENGTH(N'dbo.itemcust_mst',N'Uf_SMK069_is_peak_season') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.itemcust_mst.Uf_SMK069_is_peak_season'
    UNION ALL
    SELECT 50, 5, N'Physical Field', N'itemcust.Uf_SMK069_pos_um',
           CASE WHEN COL_LENGTH(N'dbo.itemcust_mst',N'Uf_SMK069_pos_um') IS NULL THEN N'FAIL' ELSE N'PASS' END,
           N'dbo.itemcust_mst.Uf_SMK069_pos_um'

    UNION ALL

    /* ----------------------------------------------------------------------
       6. Generated trigger sanity
       ---------------------------------------------------------------------- */
    SELECT
        60,
        1,
        N'Mongoose Trigger',
        N'temp table Peak alignment',
        CASE
            WHEN NOT EXISTS
            (
                SELECT 1
                FROM sys.triggers AS t
                WHERE t.parent_id = OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst')
            ) THEN N'WARN'
            WHEN EXISTS
            (
                SELECT 1
                FROM sys.triggers AS t
                WHERE t.parent_id = OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst')
                  AND CHARINDEX(
                      N'is_peak_season',
                      COALESCE(OBJECT_DEFINITION(t.object_id),N'')
                  ) > 0
            ) THEN N'PASS'
            ELSE N'WARN'
        END,
        CASE
            WHEN NOT EXISTS
            (
                SELECT 1
                FROM sys.triggers AS t
                WHERE t.parent_id = OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst')
            ) THEN N'No trigger found'
            WHEN EXISTS
            (
                SELECT 1
                FROM sys.triggers AS t
                WHERE t.parent_id = OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst')
                  AND CHARINDEX(
                      N'is_peak_season',
                      COALESCE(OBJECT_DEFINITION(t.object_id),N'')
                  ) > 0
            ) THEN N'At least one table trigger contains is_peak_season'
            ELSE N'CHECK / regenerate Mongoose metadata trigger'
        END

    UNION ALL

    /* ----------------------------------------------------------------------
       7. Mapping view definition hash
       ---------------------------------------------------------------------- */
    SELECT
        70,
        1,
        N'Audit',
        N'Mapping view SHA-256',
        N'INFO',
        CONVERT(VARCHAR(64),
            HASHBYTES(
                'SHA2_256',
                CONVERT(VARBINARY(MAX),
                    COALESCE(
                        OBJECT_DEFINITION(OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')),
                        N''
                    )
                )
            ),
            2
        )
) AS q(sort_group,sort_item,check_group,check_name,result,detail)
ORDER BY q.sort_group, q.sort_item;
