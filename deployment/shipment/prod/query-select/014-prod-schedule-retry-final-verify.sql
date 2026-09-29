/* SMK Query Select Execution - PROD schedule/retry final table verification
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst', N'U') IS NOT NULL
         THEN N'PASS' ELSE N'FAIL' END AS ScheduleTable,

    CASE WHEN (
        SELECT COUNT(*)
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst')
    ) = 25 THEN N'PASS' ELSE N'FAIL' END AS ScheduleColumns25,

    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst')
          AND name = N'ScheduleCode'
          AND TYPE_NAME(user_type_id) = N'nvarchar'
          AND max_length = 60
          AND is_nullable = 0
    ) THEN N'PASS' ELSE N'FAIL' END AS ScheduleCodeNvarchar30,

    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst')
          AND name = N'ScheduleName'
          AND TYPE_NAME(user_type_id) = N'nvarchar'
          AND max_length = 200
          AND is_nullable = 0
    ) THEN N'PASS' ELSE N'FAIL' END AS ScheduleNameNvarchar100,

    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst')
          AND name = N'LastMessage'
          AND TYPE_NAME(user_type_id) = N'nvarchar'
          AND max_length = 2000
    ) THEN N'PASS' ELSE N'FAIL' END AS LastMessageNvarchar1000,

    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.indexes AS i
        JOIN sys.index_columns AS ic1
          ON ic1.object_id = i.object_id
         AND ic1.index_id = i.index_id
         AND ic1.key_ordinal = 1
        JOIN sys.columns AS c1
          ON c1.object_id = ic1.object_id
         AND c1.column_id = ic1.column_id
        JOIN sys.index_columns AS ic2
          ON ic2.object_id = i.object_id
         AND ic2.index_id = i.index_id
         AND ic2.key_ordinal = 2
        JOIN sys.columns AS c2
          ON c2.object_id = ic2.object_id
         AND c2.column_id = ic2.column_id
        WHERE i.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst')
          AND i.is_primary_key = 1
          AND i.is_unique = 1
          AND c1.name = N'SiteRef'
          AND c2.name = N'ScheduleCode'
    ) THEN N'PASS' ELSE N'FAIL' END AS PrimaryKeySiteSchedule,

    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.indexes AS i
        JOIN sys.index_columns AS ic
          ON ic.object_id = i.object_id
         AND ic.index_id = i.index_id
        JOIN sys.columns AS c
          ON c.object_id = ic.object_id
         AND c.column_id = ic.column_id
        WHERE i.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst')
          AND i.is_unique = 1
          AND ic.key_ordinal = 1
          AND ic.is_included_column = 0
          AND c.name = N'RowPointer'
          AND NOT EXISTS (
              SELECT 1
              FROM sys.index_columns AS ic2
              WHERE ic2.object_id = i.object_id
                AND ic2.index_id = i.index_id
                AND ic2.key_ordinal > 1
          )
    ) THEN N'PASS' ELSE N'FAIL' END AS RowPointerUniqueSemantic,

    CASE WHEN (
        SELECT COUNT(*)
        FROM sys.triggers
        WHERE parent_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst')
          AND is_ms_shipped = 0
          AND is_disabled = 0
    ) = 3 THEN N'PASS' ELSE N'FAIL' END AS ScheduleTriggers3,

    CASE WHEN NOT EXISTS (
        SELECT 1 FROM dbo.ue_SMK069_shipment_schedule_mst
    ) THEN N'PASS' ELSE N'FAIL' END AS ScheduleEmptyBaseline,

    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst')
          AND name = N'LastError'
          AND TYPE_NAME(user_type_id) = N'nvarchar'
          AND max_length = 2000
    ) THEN N'PASS' ELSE N'FAIL' END AS RetryLastErrorNvarchar1000
