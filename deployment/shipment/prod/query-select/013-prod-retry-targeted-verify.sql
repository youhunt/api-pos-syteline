/* SMK Query Select Execution - PROD retry-table targeted verification
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    (SELECT c.max_length
     FROM sys.columns AS c
     WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst')
       AND c.name = N'LastError') AS LastErrorBytes,

    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.indexes AS i
        JOIN sys.index_columns AS ic
          ON ic.object_id = i.object_id
         AND ic.index_id = i.index_id
        JOIN sys.columns AS c
          ON c.object_id = ic.object_id
         AND c.column_id = ic.column_id
        WHERE i.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst')
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

    (SELECT TOP (1) i.name
     FROM sys.indexes AS i
     JOIN sys.index_columns AS ic
       ON ic.object_id = i.object_id
      AND ic.index_id = i.index_id
     JOIN sys.columns AS c
       ON c.object_id = ic.object_id
      AND c.column_id = ic.column_id
     WHERE i.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst')
       AND i.is_unique = 1
       AND ic.key_ordinal = 1
       AND c.name = N'RowPointer') AS RowPointerIndexName
