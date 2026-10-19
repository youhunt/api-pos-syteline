/* =============================================================================
   SMK069 - SITE ISOLATION AUDIT (CANDIDATE FINDER)
   Date : 19 Oct 2026
   Mode : READ ONLY

   Purpose:
   Find SQL modules that reference SMK069 custom objects and may require manual
   SiteRef review. This report does NOT automatically declare a defect.
   ============================================================================= */

;WITH M AS
(
    SELECT
        o.type_desc,
        QUOTENAME(OBJECT_SCHEMA_NAME(o.object_id)) + N'.' + QUOTENAME(o.name) AS object_name,
        sm.definition
    FROM sys.objects AS o
    INNER JOIN sys.sql_modules AS sm
        ON sm.object_id = o.object_id
    WHERE sm.definition LIKE N'%SMK069%'
)
SELECT
    type_desc,
    object_name,
    CASE WHEN definition LIKE N'%SiteRef%' OR definition LIKE N'%site_ref%'
         THEN N'YES' ELSE N'NO' END AS mentions_site_column,
    CASE WHEN definition LIKE N'%CONTEXT_INFO()%'
         THEN N'YES' ELSE N'NO' END AS uses_context_info,
    CASE WHEN definition LIKE N'%SetSiteSp%'
         THEN N'YES' ELSE N'NO' END AS calls_set_site_sp,
    CASE
        WHEN (definition LIKE N'%_mst%' OR definition LIKE N'%SMK069%')
         AND definition NOT LIKE N'%SiteRef%'
         AND definition NOT LIKE N'%site_ref%'
        THEN N'REVIEW'
        ELSE N'CHECK'
    END AS audit_status
FROM M
ORDER BY
    CASE
        WHEN (definition LIKE N'%_mst%' OR definition LIKE N'%SMK069%')
         AND definition NOT LIKE N'%SiteRef%'
         AND definition NOT LIKE N'%site_ref%'
        THEN 0 ELSE 1
    END,
    type_desc,
    object_name;

/* Physical-table key review: site-owned custom tables whose unique indexes
   do not include SiteRef should be manually assessed. */
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.is_unique,
    STRING_AGG(c.name, N', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS key_columns,
    CASE
        WHEN MAX(CASE WHEN c.name IN (N'SiteRef', N'site_ref') THEN 1 ELSE 0 END) = 1
        THEN N'PASS'
        ELSE N'REVIEW'
    END AS site_key_status
FROM sys.indexes AS i
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
   AND ic.is_included_column = 0
INNER JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE i.is_unique = 1
  AND OBJECT_NAME(i.object_id) LIKE N'%SMK069%'
GROUP BY i.object_id, i.name, i.is_unique
ORDER BY table_name, index_name;