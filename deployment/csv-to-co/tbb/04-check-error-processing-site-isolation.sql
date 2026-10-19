/* =============================================================================
   SMK069 TBB - DIAGNOSE ERROR PROCESSING SITE ISOLATION
   Date  : 19 Oct 2026
   Scope : ue_SMK069TempSales / SMK API SALES ERROR PROCESSING primary grid
   Mode  : READ ONLY / Query Select
   ============================================================================= */

SELECT
    q.check_group,
    q.check_name,
    q.result,
    q.detail
FROM
(
    SELECT
        10 AS sort_group,
        1 AS sort_item,
        N'Context' AS check_group,
        N'Active site' AS check_name,
        N'INFO' AS result,
        RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0)) AS detail

    UNION ALL

    SELECT
        20,
        ROW_NUMBER() OVER (ORDER BY SiteRef),
        N'Temp Data',
        N'SiteRef=' + COALESCE(CONVERT(NVARCHAR(30), SiteRef), N'<NULL>'),
        N'INFO',
        N'rows=' + CONVERT(NVARCHAR(30), COUNT(*))
    FROM dbo.ue_SMK069_temp_sales_mst
    GROUP BY SiteRef

    UNION ALL

    SELECT
        30,
        1,
        N'Multi-Site Object',
        N'generated site view candidate',
        CASE
            WHEN OBJECT_ID(N'dbo.ue_SMK069_temp_sales', N'V') IS NOT NULL THEN N'PASS'
            ELSE N'INFO'
        END,
        CASE
            WHEN OBJECT_ID(N'dbo.ue_SMK069_temp_sales', N'V') IS NOT NULL
                THEN N'dbo.ue_SMK069_temp_sales view exists'
            ELSE N'No dbo.ue_SMK069_temp_sales view found; inspect SQL Tables / Application Schema Tables Metadata / View Management'
        END

    UNION ALL

    SELECT
        40,
        1,
        N'Cross-Site Visibility',
        N'rows outside active site',
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_temp_sales_mst AS t
                WHERE RTRIM(CONVERT(NVARCHAR(8), t.SiteRef)) <>
                      RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
            )
            THEN N'WARN'
            ELSE N'PASS'
        END,
        N'Physical _mst table can contain rows for multiple sites; UI/IDO must isolate the active site'
) AS q(sort_group, sort_item, check_group, check_name, result, detail)
ORDER BY q.sort_group, q.sort_item
