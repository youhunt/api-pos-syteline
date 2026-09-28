/* SMK Query Select Execution - PROD config baseline verification
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst', N'U') IS NOT NULL
         THEN N'PASS' ELSE N'FAIL' END AS ConfigTable,
    CASE WHEN (SELECT COUNT(*) FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')) = 24
         THEN N'PASS' ELSE N'FAIL' END AS ColumnCount24,
    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')
          AND name = N'IX_ue_SMK069_shipment_api_config_mst_RowPointer'
          AND is_unique = 1
          AND is_unique_constraint = 1
    ) THEN N'PASS' ELSE N'FAIL' END AS RowPointerUnique,
    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst')
          AND name = N'RowPointer'
          AND is_rowguidcol = 0
          AND is_nullable = 0
    ) THEN N'PASS' ELSE N'FAIL' END AS RowPointerShape,
    CASE WHEN NOT EXISTS (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_api_config_mst
    ) THEN N'PASS' ELSE N'FAIL' END AS EmptyBaseline
