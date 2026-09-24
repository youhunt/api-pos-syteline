/* =============================================================================
   SMK069 PROD POST-DEPLOY VERIFY
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-24
   Mode  : READ ONLY. Run in Query Select after runtime deployment.
   ============================================================================= */

SET NOCOUNT ON;

/* 1. Runtime objects */
SELECT
    o.name AS object_name,
    o.type_desc,
    o.modify_date,
    CASE WHEN o.object_id IS NULL THEN N'MISSING' ELSE N'OK' END AS status
FROM
(
    VALUES
      (N'SMK069CsvSplitLine'),
      (N'SMK069ImportCsvFileSp'),
      (N'SMK069ValidateCustomerSp'),
      (N'SMK069ProcessCustomerOrderSp'),
      (N'SMK069ProcessBatchCustomerOrdersSp'),
      (N'SMK069ReceivePosSalesJsonCoreSp'),
      (N'SMK069ReceivePosSalesJsonSp'),
      (N'SMK069RunCsvTestBatchSp')
) AS x(name)
LEFT JOIN sys.objects AS o
    ON o.schema_id = SCHEMA_ID(N'dbo')
   AND o.name = x.name
ORDER BY x.name;

/* 2. Current-state markers */
SELECT
    N'Core Peak before mapping' AS check_name,
    CASE WHEN CHARINDEX(
        N'Peak Season MUST be persisted before #MapView',
        COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS result

UNION ALL
SELECT
    N'Public Receive POS-204 reused-batch fallback',
    CASE WHEN CHARINDEX(
        N'PATCH-34: synthesize POS-204 from payload CustPO',
        COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END

UNION ALL
SELECT
    N'Public Receive ValidationStatus gate',
    CASE WHEN CHARINDEX(
        N'ValidationStatus',
        COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END

UNION ALL
SELECT
    N'Per-order Blanket line insert',
    CASE WHEN CHARINDEX(
        N'INSERT INTO dbo.co_bln_mst',
        COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END

UNION ALL
SELECT
    N'Per-order created_co_num persistence',
    CASE WHEN CHARINDEX(
        N'created_co_num',
        COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END

UNION ALL
SELECT
    N'Batch POS-302 no silent success',
    CASE WHEN CHARINDEX(
        N'[POS-302]',
        COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessBatchCustomerOrdersSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END

UNION ALL
SELECT
    N'CSV runner Peak Season',
    CASE WHEN CHARINDEX(
        N'is_peak_season',
        COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END

UNION ALL
SELECT
    N'CSV parser Peak alias',
    CASE WHEN CHARINDEX(
        N'is_peak_seson',
        COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ImportCsvFileSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END;

/* 3. Public Receive parameter order - must stay compatible */
SELECT
    p.parameter_id,
    p.name AS parameter_name,
    TYPE_NAME(p.user_type_id) AS data_type,
    p.max_length,
    p.is_output
FROM sys.parameters AS p
WHERE p.object_id = OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')
ORDER BY p.parameter_id;

/* Expected:
   1 @SourceSystem
   2 @BatchId
   3 @PayloadJson
   4 @ReceivedBy
   5 @ReceivedRows OUT
   6 @TotalOrders OUT
   7 @ValidOrders OUT
   8 @ErrorOrders OUT
   9 @TransferredRows OUT
  10 @Infobar OUT
  11 @ProcessedOrders OUT
  12 @ProcessErrors OUT
  13 @CreatedCoNums OUT
  14 @ThrowOnBusinessError
*/

/* 4. Mapping-view contract */
SELECT
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    c.max_length,
    c.precision,
    c.scale
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')
ORDER BY c.column_id;

/* 5. Peak Season physical contract */
SELECT
    N'inbound.is_peak_season' AS field_name,
    CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'is_peak_season') IS NULL
         THEN N'MISSING' ELSE N'OK' END AS status
UNION ALL
SELECT
    N'temp.is_peak_season',
    CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'is_peak_season') IS NULL
         THEN N'MISSING' ELSE N'OK' END
UNION ALL
SELECT
    N'csv_upload.is_peak_season',
    CASE WHEN COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst', N'is_peak_season') IS NULL
         THEN N'MISSING' ELSE N'OK' END
UNION ALL
SELECT
    N'itemcust.Uf_SMK069_is_peak_season',
    CASE WHEN COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_is_peak_season') IS NULL
         THEN N'MISSING' ELSE N'OK' END
UNION ALL
SELECT
    N'itemcust.Uf_SMK069_pos_um',
    CASE WHEN COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_pos_um') IS NULL
         THEN N'MISSING' ELSE N'OK' END;

/* 6. Temp trigger metadata sanity.
   is_peak_season should ideally be present after UET/Impact Schema regeneration.
   Runtime still syncs Peak after Core, but PROD metadata should be aligned. */
SELECT
    t.name AS trigger_name,
    t.is_instead_of_trigger,
    t.is_disabled,
    CASE
        WHEN CHARINDEX(
            N'is_peak_season',
            COALESCE(OBJECT_DEFINITION(t.object_id), N'')
        ) > 0 THEN N'contains is_peak_season'
        ELSE N'CHECK / REGENERATE METADATA'
    END AS peak_column_alignment
FROM sys.triggers AS t
WHERE t.parent_id = OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst')
ORDER BY t.name;

/* 7. Mapping view definition hash for DEV vs PROD comparison */
SELECT
    CONVERT(VARCHAR(64),
        HASHBYTES
        (
            'SHA2_256',
            CONVERT(VARBINARY(MAX),
                COALESCE(
                    OBJECT_DEFINITION(OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')),
                    N''
                )
            )
        ),
        2
    ) AS mapping_view_definition_sha256,
    (SELECT modify_date
     FROM sys.objects
     WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view'))
        AS mapping_view_modify_date;
