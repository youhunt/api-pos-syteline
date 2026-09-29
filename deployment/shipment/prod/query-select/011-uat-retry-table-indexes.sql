/* UAT Query Select - capture retry-table indexes/triggers
   Pure SELECT only. Run separately if the Query Select form rejects the UNION shape.
*/
SELECT TOP (100)
    i.name AS ObjectName,
    N'INDEX' AS ObjectKind,
    i.type_desc AS Detail1,
    CONVERT(NVARCHAR(10), i.is_primary_key) AS Detail2,
    CONVERT(NVARCHAR(10), i.is_unique) AS Detail3,
    c.name AS ColumnName
FROM sys.indexes AS i
JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst')
  AND i.index_id > 0
ORDER BY i.index_id, ic.key_ordinal, ic.index_column_id
