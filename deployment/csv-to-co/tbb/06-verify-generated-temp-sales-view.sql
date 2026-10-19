/* =============================================================================
   SMK069 TBB - VERIFY GENERATED MULTI-SITE TEMP SALES VIEW
   Date  : 19 Oct 2026
   Scope : dbo.ue_SMK069_temp_sales
   Mode  : READ ONLY / Query Select

   Note:
   The generated Mongoose multi-site view may intentionally NOT expose SiteRef.
   Therefore verify isolation by comparing row counts, not by selecting SiteRef
   from the generated view.
   ============================================================================= */

SELECT
    RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0)) AS ActiveSite,
    CASE
        WHEN OBJECT_ID(N'dbo.ue_SMK069_temp_sales', N'V') IS NULL THEN N'FAIL'
        ELSE N'PASS'
    END AS ViewExists,
    (
        SELECT COUNT(*)
        FROM dbo.ue_SMK069_temp_sales
    ) AS ViewRows,
    (
        SELECT COUNT(*)
        FROM dbo.ue_SMK069_temp_sales_mst AS t
        WHERE RTRIM(CONVERT(NVARCHAR(8), t.SiteRef)) =
              RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
    ) AS ExpectedActiveSiteRows,
    (
        SELECT COUNT(*)
        FROM dbo.ue_SMK069_temp_sales_mst AS t
        WHERE RTRIM(CONVERT(NVARCHAR(8), t.SiteRef)) <>
              RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
    ) AS OtherSiteRows
