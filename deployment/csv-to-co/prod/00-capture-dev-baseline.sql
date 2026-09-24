/* =============================================================================
   SMK069 DEV BASELINE CAPTURE FOR PROD MIGRATION
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-24
   Mode  : Query Select / READ ONLY
   ============================================================================= */

SET NOCOUNT ON;

/* 1. Runtime object signatures / hashes */
SELECT
    o.type_desc,
    s.name AS schema_name,
    o.name AS object_name,
    o.create_date,
    o.modify_date,
    CONVERT(VARCHAR(64),
        HASHBYTES
        (
            'SHA2_256',
            CONVERT(VARBINARY(MAX), COALESCE(OBJECT_DEFINITION(o.object_id), N''))
        ),
        2
    ) AS definition_sha256
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE s.name = N'dbo'
  AND o.name IN
  (
      N'SMK069CsvSplitLine',
      N'SMK069ImportCsvFileSp',
      N'SMK069ValidateCustomerSp',
      N'SMK069ProcessCustomerOrderSp',
      N'SMK069ProcessBatchCustomerOrdersSp',
      N'SMK069ReceivePosSalesJsonCoreSp',
      N'SMK069ReceivePosSalesJsonSp',
      N'SMK069RunCsvTestBatchSp',
      N'ue_SMK069_pos_sales_inbound_mapping_view'
  )
ORDER BY o.name;

/* 2. Exact mapping-view definition - owned by Eva / SMK */
SELECT
    OBJECT_DEFINITION
    (
        OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')
    ) AS mapping_view_definition;

/* 3. Custom table/view columns */
SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS schema_name,
    OBJECT_NAME(c.object_id) AS object_name,
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS user_type,
    TYPE_NAME(c.system_type_id) AS system_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    dc.definition AS default_definition
FROM sys.columns AS c
LEFT JOIN sys.default_constraints AS dc
    ON dc.parent_object_id = c.object_id
   AND dc.parent_column_id = c.column_id
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')
)
ORDER BY object_name, c.column_id;

/* 4. Generated/custom trigger definitions for custom tables */
SELECT
    OBJECT_NAME(t.parent_id) AS parent_object,
    t.name AS trigger_name,
    t.is_instead_of_trigger,
    t.is_disabled,
    t.create_date,
    t.modify_date,
    OBJECT_DEFINITION(t.object_id) AS trigger_definition
FROM sys.triggers AS t
WHERE t.parent_id IN
(
    OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst')
)
ORDER BY parent_object, trigger_name;

/* 5. Peak Season UET physical columns */
SELECT
    c.column_id,
    c.name,
    TYPE_NAME(c.user_type_id) AS user_type,
    TYPE_NAME(c.system_type_id) AS system_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    dc.definition AS default_definition
FROM sys.columns AS c
LEFT JOIN sys.default_constraints AS dc
    ON dc.parent_object_id = c.object_id
   AND dc.parent_column_id = c.column_id
WHERE c.object_id = OBJECT_ID(N'dbo.itemcust_mst')
  AND c.name IN
  (
      N'Uf_SMK069_is_peak_season',
      N'Uf_SMK069_pos_um'
  )
ORDER BY c.name;

/* 6. Public method parameter contract in SQL */
SELECT
    p.parameter_id,
    p.name AS parameter_name,
    TYPE_NAME(p.user_type_id) AS data_type,
    p.max_length,
    p.precision,
    p.scale,
    p.is_output
FROM sys.parameters AS p
WHERE p.object_id = OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')
ORDER BY p.parameter_id;
