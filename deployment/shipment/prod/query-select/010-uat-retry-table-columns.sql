/* UAT Query Select - capture current retry-table physical contract
   Pure SELECT only. No trailing semicolon.
*/
SELECT TOP (100)
    c.column_id,
    c.name AS ColumnName,
    t.name AS TypeName,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    c.is_identity,
    c.is_rowguidcol,
    ISNULL(dc.definition, N'') AS DefaultDefinition
FROM sys.columns AS c
JOIN sys.types AS t
    ON t.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints AS dc
    ON dc.parent_object_id = c.object_id
   AND dc.parent_column_id = c.column_id
WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst')
ORDER BY c.column_id
