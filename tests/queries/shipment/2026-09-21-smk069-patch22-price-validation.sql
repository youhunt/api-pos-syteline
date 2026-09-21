/* SMK Query Select Execution - pure SELECT only, no trailing semicolon */
SELECT
    CASE
        WHEN CHARINDEX(
            N'SMK069-PRICE-POSITIVE-R1',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P')), N'')
        ) > 0
        THEN N'PASS'
        ELSE N'FAIL'
    END AS Patch22Marker,
    CASE
        WHEN CHARINDEX(
            N'ISNULL(pv.Price, 0) <= 0',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P')), N'')
        ) > 0
        THEN N'PASS'
        ELSE N'FAIL'
    END AS PriceGuard
