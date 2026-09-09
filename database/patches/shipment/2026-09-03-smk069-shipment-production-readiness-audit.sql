/*
SMK069 Shipment Production Readiness Audit
Date: 2026-09-03

Purpose
-------
Read-only tenant audit before wiring the server-side HTTP transport to the
stable Shipment Build / Prepare / Complete procedures.

This script does NOT:
- alter any object;
- POST to POS;
- update the shipment outbound log;
- update shipment_mst.SMK069_Uf_api_post.

Run from the target CSI application database/session so CONTEXT_INFO contains
the active Site.
*/

SET NOCOUNT ON;

DECLARE @Site SiteType;
SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));

PRINT '=== SMK069 Shipment Production Readiness Audit ===';
PRINT 'Active Site from CONTEXT_INFO = [' + ISNULL(CONVERT(NVARCHAR(50), @Site), '') + ']';

IF NULLIF(RTRIM(CONVERT(NVARCHAR(50), @Site)), '') IS NULL
BEGIN
    RAISERROR(
        'Active Site is blank. Run this audit from a CSI/Mongoose session with site context.',
        16,
        1
    );
    RETURN;
END;

EXEC SetSiteSp @Site, NULL;


/* 1. Shipment SP site-context audit */
SELECT
    p.name AS procedure_name,
    CASE WHEN m.definition LIKE '%CONTEXT_INFO%' THEN 'YES' ELSE 'NO' END AS HasSiteContext,
    CASE WHEN m.definition LIKE '%SetSiteSp%' THEN 'YES' ELSE 'NO' END AS HasSetSiteSp,
    CASE WHEN m.definition LIKE '%site_ref%' OR m.definition LIKE '%SiteRef%'
         THEN 'YES' ELSE 'NO' END AS HasSiteReference,
    CASE WHEN m.definition LIKE '%''DEFAULT''%' THEN 'CHECK' ELSE 'OK' END AS HasDefaultLiteral
FROM sys.procedures p
JOIN sys.sql_modules m
    ON m.object_id = p.object_id
WHERE p.name IN
(
    'SMK069BuildShipmentJsonSp',
    'SMK069PrepareShipmentSendSp',
    'SMK069CompleteShipmentSendSp'
)
ORDER BY p.name;


/* 2. Exact parameters needed by the next orchestration step */
SELECT
    o.name AS procedure_name,
    p.parameter_id,
    p.name AS parameter_name,
    TYPE_NAME(p.user_type_id) AS data_type,
    p.max_length,
    p.precision,
    p.scale,
    p.is_output
FROM sys.objects o
JOIN sys.parameters p
    ON p.object_id = o.object_id
WHERE o.type = 'P'
  AND o.name IN
  (
      'SMK069BuildShipmentJsonSp',
      'SMK069PrepareShipmentSendSp',
      'SMK069CompleteShipmentSendSp'
  )
ORDER BY o.name, p.parameter_id;


/* 3. Shipment view must expose site_ref */
SELECT
    OBJECT_SCHEMA_NAME(v.object_id) AS schema_name,
    v.name AS view_name,
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    c.max_length
FROM sys.views v
JOIN sys.columns c
    ON c.object_id = v.object_id
WHERE v.name = 'SMK069_ShipmentAPI_mst'
ORDER BY c.column_id;

SELECT
    CASE
        WHEN OBJECT_ID('dbo.SMK069_ShipmentAPI_mst', 'V') IS NULL
            THEN 'FAIL - view missing'
        WHEN COL_LENGTH('dbo.SMK069_ShipmentAPI_mst', 'site_ref') IS NULL
            THEN 'FAIL - site_ref missing'
        ELSE 'PASS'
    END AS ShipmentViewSiteRefCheck;


/* 4. Outbound log columns */
IF OBJECT_ID('dbo.ue_SMK069_shipment_api_log_mst', 'U') IS NOT NULL
BEGIN
    SELECT
        c.column_id,
        c.name AS column_name,
        TYPE_NAME(c.user_type_id) AS data_type,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable
    FROM sys.columns c
    WHERE c.object_id = OBJECT_ID('dbo.ue_SMK069_shipment_api_log_mst')
    ORDER BY c.column_id;
END
ELSE
BEGIN
    SELECT 'FAIL - dbo.ue_SMK069_shipment_api_log_mst missing' AS LogTableCheck;
END;


/* 5. Pending Shipment snapshot for the current Site */
IF OBJECT_ID('dbo.SMK069_ShipmentAPI_mst', 'V') IS NOT NULL
   AND COL_LENGTH('dbo.SMK069_ShipmentAPI_mst', 'site_ref') IS NOT NULL
BEGIN
    DECLARE @Sql NVARCHAR(MAX);

    SET @Sql = N'
        SELECT
            site_ref,
            DN_No,
            MAX(Delivery_date) AS Delivery_date,
            MAX(doc_no) AS doc_no,
            COUNT(*) AS detail_rows,
            SUM(CASE WHEN ISNULL(shipment_qty, 0) > 0 THEN 1 ELSE 0 END) AS positive_qty_rows,
            MAX(ISNULL(Api_post, 0)) AS Api_post
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @AuditSite
          AND ISNULL(Api_post, 0) = 0
        GROUP BY site_ref, DN_No
        ORDER BY DN_No;';

    EXEC sp_executesql
        @Sql,
        N'@AuditSite SiteType',
        @AuditSite = @Site;
END;


/* 6. Logical log key collision check: SiteRef + ShipmentId */
IF OBJECT_ID('dbo.ue_SMK069_shipment_api_log_mst', 'U') IS NOT NULL
BEGIN
    SELECT
        SiteRef,
        ShipmentId,
        SUM(CASE WHEN ProcessStatus = 'N' THEN 1 ELSE 0 END) AS NewCount,
        SUM(CASE WHEN ProcessStatus = 'S' THEN 1 ELSE 0 END) AS SuccessCount,
        SUM(CASE WHEN ProcessStatus = 'E' THEN 1 ELSE 0 END) AS ErrorCount,
        COUNT(*) AS TotalAttempts
    FROM dbo.ue_SMK069_shipment_api_log_mst
    WHERE SiteRef = @Site
    GROUP BY SiteRef, ShipmentId
    HAVING SUM(CASE WHEN ProcessStatus = 'N' THEN 1 ELSE 0 END) > 1
        OR SUM(CASE WHEN ProcessStatus = 'S' THEN 1 ELSE 0 END) > 1
    ORDER BY ShipmentId;
END;

PRINT '=== End SMK069 Shipment Production Readiness Audit ===';
