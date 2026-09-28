/* SMK Query Select Execution - PROD UDT dependency check
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    CASE WHEN TYPE_ID(N'UsernameType') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS UsernameType,
    CASE WHEN TYPE_ID(N'CurrentDateType') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS CurrentDateType,
    CASE WHEN TYPE_ID(N'RowPointerType') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS RowPointerType,
    CASE WHEN TYPE_ID(N'FlagNyType') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS FlagNyType,
    CASE WHEN TYPE_ID(N'SiteType') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS SiteType
