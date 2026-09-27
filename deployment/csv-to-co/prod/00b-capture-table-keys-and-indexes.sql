/* =============================================================================
   SMK069 DEV TABLE METADATA CAPTURE - QUERY SELECT COMPATIBLE
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-28

   IMPORTANT
   ---------
   Designed for Infor SyteLine "Query Select":
   - exactly ONE SELECT statement
   - no DECLARE
   - no temp table
   - no DDL/DML
   - returns column, identity, default, PK/index and FK metadata in one resultset
   ============================================================================= */

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
    CASE WHEN ic.column_id IS NULL THEN 0 ELSE 1 END AS is_identity,
    CONVERT(NVARCHAR(100), ic.seed_value) AS identity_seed,
    CONVERT(NVARCHAR(100), ic.increment_value) AS identity_increment,
    dc.definition AS default_definition,

    ISNULL
    (
        STUFF
        (
            (
                SELECT
                    N' | '
                    + ISNULL(i.name, N'<unnamed>')
                    + N'; type=' + i.type_desc
                    + N'; unique=' + CONVERT(NVARCHAR(1), i.is_unique)
                    + N'; pk=' + CONVERT(NVARCHAR(1), i.is_primary_key)
                    + N'; unique_constraint=' + CONVERT(NVARCHAR(1), i.is_unique_constraint)
                    + N'; key_ordinal=' + CONVERT(NVARCHAR(10), ixc.key_ordinal)
                    + N'; included=' + CONVERT(NVARCHAR(1), ixc.is_included_column)
                    + N'; desc=' + CONVERT(NVARCHAR(1), ixc.is_descending_key)
                    + CASE
                          WHEN i.has_filter = 1
                          THEN N'; filter=' + ISNULL(i.filter_definition, N'')
                          ELSE N''
                      END
                FROM sys.index_columns AS ixc
                INNER JOIN sys.indexes AS i
                    ON i.object_id = ixc.object_id
                   AND i.index_id  = ixc.index_id
                WHERE ixc.object_id = c.object_id
                  AND ixc.column_id = c.column_id
                  AND i.type > 0
                  AND i.is_hypothetical = 0
                ORDER BY
                    i.name,
                    ixc.is_included_column,
                    ixc.key_ordinal
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'),
            1,
            3,
            N''
        ),
        N''
    ) AS index_metadata,

    ISNULL
    (
        STUFF
        (
            (
                SELECT
                    N' | '
                    + fk.name
                    + N' -> '
                    + OBJECT_SCHEMA_NAME(fk.referenced_object_id)
                    + N'.'
                    + OBJECT_NAME(fk.referenced_object_id)
                    + N'(' + rc.name + N')'
                    + N'; delete=' + fk.delete_referential_action_desc
                    + N'; update=' + fk.update_referential_action_desc
                FROM sys.foreign_key_columns AS fkc
                INNER JOIN sys.foreign_keys AS fk
                    ON fk.object_id = fkc.constraint_object_id
                INNER JOIN sys.columns AS pc
                    ON pc.object_id = fkc.parent_object_id
                   AND pc.column_id = fkc.parent_column_id
                INNER JOIN sys.columns AS rc
                    ON rc.object_id = fkc.referenced_object_id
                   AND rc.column_id = fkc.referenced_column_id
                WHERE fkc.parent_object_id = c.object_id
                  AND pc.column_id = c.column_id
                ORDER BY fk.name
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'),
            1,
            3,
            N''
        ),
        N''
    ) AS fk_metadata

FROM sys.columns AS c
LEFT JOIN sys.identity_columns AS ic
    ON ic.object_id = c.object_id
   AND ic.column_id = c.column_id
LEFT JOIN sys.default_constraints AS dc
    ON dc.parent_object_id = c.object_id
   AND dc.parent_column_id = c.column_id
WHERE OBJECT_SCHEMA_NAME(c.object_id) = N'dbo'
  AND OBJECT_NAME(c.object_id) IN
  (
      N'ue_SMK069_pos_sales_inbound_mst',
      N'ue_SMK069_temp_sales_mst',
      N'ue_SMK069_pos_csv_batch_mst',
      N'ue_SMK069_pos_csv_upload_mst'
  )
ORDER BY
    object_name,
    c.column_id;
