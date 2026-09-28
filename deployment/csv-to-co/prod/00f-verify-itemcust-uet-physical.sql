SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS schema_name,
    OBJECT_NAME(c.object_id) AS table_name,
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
WHERE c.object_id = OBJECT_ID(N'dbo.itemcust_mst')
  AND c.name IN
  (
      N'Uf_SMK069_is_peak_season',
      N'Uf_SMK069_pos_um'
  )
ORDER BY c.name;
