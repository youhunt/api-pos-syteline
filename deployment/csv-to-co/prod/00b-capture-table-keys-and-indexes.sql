/* =============================================================================
   SMK069 DEV TABLE KEY / IDENTITY / INDEX CAPTURE
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-28
   Mode  : READ ONLY / Query Select

   Purpose
   -------
   Capture the remaining physical-table metadata needed to build exact PROD
   CREATE TABLE scripts without guessing:
   - identity columns
   - primary keys
   - unique constraints/indexes
   - non-unique indexes
   - included columns
   ============================================================================= */

SET NOCOUNT ON;

DECLARE @Objects TABLE (object_name SYSNAME PRIMARY KEY);
INSERT @Objects(object_name) VALUES
    (N'ue_SMK069_pos_sales_inbound_mst'),
    (N'ue_SMK069_temp_sales_mst'),
    (N'ue_SMK069_pos_csv_batch_mst'),
    (N'ue_SMK069_pos_csv_upload_mst');

/* 1. Identity columns */
SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS schema_name,
    OBJECT_NAME(c.object_id) AS object_name,
    c.column_id,
    c.name AS column_name,
    ic.seed_value,
    ic.increment_value,
    ic.last_value,
    ic.is_not_for_replication
FROM sys.columns AS c
INNER JOIN sys.identity_columns AS ic
    ON ic.object_id = c.object_id
   AND ic.column_id = c.column_id
WHERE OBJECT_NAME(c.object_id) IN (SELECT object_name FROM @Objects)
ORDER BY object_name, c.column_id;

/* 2. Primary keys / unique constraints */
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS object_name,
    i.name AS index_name,
    i.is_primary_key,
    i.is_unique_constraint,
    i.is_unique,
    i.type_desc,
    ic.key_ordinal,
    c.name AS column_name,
    ic.is_descending_key
FROM sys.indexes AS i
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
INNER JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE OBJECT_NAME(i.object_id) IN (SELECT object_name FROM @Objects)
  AND (i.is_primary_key = 1 OR i.is_unique_constraint = 1 OR i.is_unique = 1)
  AND ic.is_included_column = 0
ORDER BY object_name, index_name, ic.key_ordinal;

/* 3. All non-heap indexes, including INCLUDE columns and filters */
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS object_name,
    i.name AS index_name,
    i.type_desc,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint,
    i.has_filter,
    i.filter_definition,
    ic.key_ordinal,
    ic.is_included_column,
    c.name AS column_name,
    ic.is_descending_key
FROM sys.indexes AS i
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
INNER JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE OBJECT_NAME(i.object_id) IN (SELECT object_name FROM @Objects)
  AND i.type > 0
  AND i.is_hypothetical = 0
ORDER BY object_name, index_name, ic.is_included_column, ic.key_ordinal, c.column_id;

/* 4. Foreign keys, if any */
SELECT
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS schema_name,
    OBJECT_NAME(fk.parent_object_id) AS object_name,
    fk.name AS fk_name,
    pc.name AS parent_column,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referenced_schema,
    OBJECT_NAME(fk.referenced_object_id) AS referenced_object,
    rc.name AS referenced_column,
    fk.delete_referential_action_desc,
    fk.update_referential_action_desc
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
    ON fkc.constraint_object_id = fk.object_id
INNER JOIN sys.columns AS pc
    ON pc.object_id = fkc.parent_object_id
   AND pc.column_id = fkc.parent_column_id
INNER JOIN sys.columns AS rc
    ON rc.object_id = fkc.referenced_object_id
   AND rc.column_id = fkc.referenced_column_id
WHERE OBJECT_NAME(fk.parent_object_id) IN (SELECT object_name FROM @Objects)
ORDER BY object_name, fk_name, fkc.constraint_column_id;
