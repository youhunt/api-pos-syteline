/* =============================================================================
   SMK069 - Shipment Patch 13 - ROOT CAUSE AUDIT (READ ONLY)
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Scope   : Shipment Outbound SyteLine -> POS API only
   Purpose : Capture the exact tenant evidence needed before retrying P96330,
             P96331, or P96332.

   CURRENT INCIDENT
   ----------------
   P96330 / P96332 : HTTP 404 + Complete Shipment nvarchar -> bigint exception
   P96331          : no DOC_NO / Customer Order

   SAFETY
   ------
   * READ ONLY. This script contains no INSERT/UPDATE/DELETE/MERGE/DDL.
   * It does NOT call Prepare, HTTP transport, Complete, Reset Retry, or Run Now.
   * It does NOT expose AuthValue, username, password, or bearer token.
   * Do not retry a Shipment based only on this script. Review the evidence first.

   Run this from a tenant SQL/query tool that can execute SELECT/metadata queries.
   Keep the result sets as the tenant capture for the follow-up minimal patch.
   ============================================================================= */

SET NOCOUNT ON;

/* =============================================================================
   1. CURRENT SITE + ACTIVE SHIPMENT CONFIG
      EndpointUrl is intentionally exposed; AuthValue is intentionally omitted.
   ============================================================================= */
SELECT
    RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0)) AS CurrentSite,
    c.SiteRef,
    c.ApiName,
    c.IsActive,
    c.SchedulerEnabled,
    c.EndpointUrl,
    c.LoginUrl,
    c.HttpMethod,
    c.ContentType,
    c.SuccessMode,
    c.TimeoutSeconds,
    c.MaxBatchSize,
    c.MaxAttempts,
    c.BackoffBaseMinutes,
    c.BackoffCapMinutes,
    c.RecordDate
FROM dbo.ue_SMK069_shipment_api_config_mst AS c
WHERE c.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.ApiName = N'SHIPMENT'
ORDER BY c.IsActive DESC, c.RecordDate DESC;

/* =============================================================================
   2. PROCEDURE PARAMETER METADATA
      This is the authoritative tenant signature evidence.
   ============================================================================= */
SELECT
    OBJECT_SCHEMA_NAME(p.object_id) AS SchemaName,
    OBJECT_NAME(p.object_id) AS ObjectName,
    p.parameter_id,
    p.name AS ParameterName,
    TYPE_NAME(p.user_type_id) AS UserTypeName,
    TYPE_NAME(p.system_type_id) AS SystemTypeName,
    p.max_length,
    p.precision,
    p.scale,
    p.is_output
FROM sys.parameters AS p
WHERE p.object_id IN
(
    OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp', N'P'),
    OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P'),
    OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')
)
ORDER BY ObjectName, p.parameter_id;

/* =============================================================================
   3. EXACT TENANT DEFINITIONS
      Preserve these result cells before any patch is written.
   ============================================================================= */
SELECT
    N'dbo.SMK069PrepareShipmentSendSp' AS ObjectName,
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp', N'P')) AS TenantDefinition
UNION ALL
SELECT
    N'dbo.SMK069BuildShipmentJsonSp',
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P'))
UNION ALL
SELECT
    N'dbo.SMK069CompleteShipmentSendSp',
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P'))
UNION ALL
SELECT
    N'dbo.SMK069_ShipmentAPI_mst',
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069_ShipmentAPI_mst', N'V'));

/* =============================================================================
   4. COMPLETE SP - LINE 36 + CONVERSION MARKERS
      SQL Server error reports dbo.SMK069CompleteShipmentSendSp:36.
      Normalize CRLF and extract line 36 directly from the tenant definition.
   ============================================================================= */
;WITH CompleteSource AS
(
    SELECT REPLACE(
        OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')),
        CHAR(13), N''
    ) AS DefinitionText
), XmlSource AS
(
    SELECT TRY_CAST(
        N'<root><line>' +
        REPLACE(
            (SELECT DefinitionText AS [text()] FOR XML PATH(N'')),
            CHAR(10),
            N'</line><line>'
        ) +
        N'</line></root>'
        AS XML
    ) AS DefinitionXml,
    DefinitionText
    FROM CompleteSource
)
SELECT
    DefinitionXml.value(N'(/root/line[36]/text())[1]', N'NVARCHAR(4000)') AS CompleteLine36,
    CHARINDEX(N'BIGINT', UPPER(ISNULL(DefinitionText, N''))) AS FirstBigintTokenPosition,
    CHARINDEX(N'CONVERT(BIGINT', UPPER(REPLACE(ISNULL(DefinitionText, N''), N' ', N''))) AS ConvertBigintPosition,
    CHARINDEX(N'CAST(', UPPER(ISNULL(DefinitionText, N''))) AS FirstCastTokenPosition,
    CHARINDEX(N'DN_NO', UPPER(ISNULL(DefinitionText, N''))) AS FirstDnNoTokenPosition,
    CHARINDEX(N'SHIPMENTID', UPPER(ISNULL(DefinitionText, N''))) AS FirstShipmentIdTokenPosition
FROM XmlSource;

/* =============================================================================
   5. TENANT COLUMN METADATA FOR THE OBJECTS MOST LIKELY TO CROSS TYPE BOUNDARIES
   ============================================================================= */
SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName,
    OBJECT_NAME(c.object_id) AS ObjectName,
    c.column_id,
    c.name AS ColumnName,
    TYPE_NAME(c.user_type_id) AS UserTypeName,
    TYPE_NAME(c.system_type_id) AS SystemTypeName,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.columns AS c
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.SMK069_ShipmentAPI_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_shipment_api_log_mst'),
    OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst')
)
ORDER BY ObjectName, c.column_id;

/* =============================================================================
   6. INCIDENT DNs AS CURRENTLY EXPOSED BY THE SHIPMENT VIEW
      This verifies DOC_NO separately from HTTP/Complete failures.
   ============================================================================= */
SELECT
    LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))) AS DN_No,
    v.doc_no,
    COUNT(*) AS LineCount,
    SUM(ISNULL(v.shipment_qty, 0)) AS ShipmentQty,
    MIN(v.cust_code) AS CustCode,
    MIN(v.whse_code) AS WhseCode,
    MIN(v.store_code) AS StoreCode,
    MIN(v.Api_post) AS MinApiPost,
    MAX(v.Api_post) AS MaxApiPost,
    MIN(v.Api_post_date) AS FirstApiPostDate,
    MAX(v.Api_post_date) AS LastApiPostDate
FROM dbo.SMK069_ShipmentAPI_mst AS v
WHERE LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))) IN
      (N'P96330', N'P96331', N'P96332')
GROUP BY
    LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))),
    v.doc_no
ORDER BY DN_No, v.doc_no;

/* =============================================================================
   7. RETRY STATE - NO RESET, NO UPDATE
   ============================================================================= */
SELECT
    r.SiteRef,
    r.ShipmentId,
    r.AttemptCount,
    r.RetryState,
    r.FirstAttemptDate,
    r.LastAttemptDate,
    r.NextAttemptDate,
    r.LastHttpCode,
    r.LastError,
    r.RecordDate
FROM dbo.ue_SMK069_shipment_retry_mst AS r
WHERE r.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND r.ShipmentId IN (N'P96330', N'P96331', N'P96332')
ORDER BY r.ShipmentId;

/* =============================================================================
   8. API LOG ROWS, ONLY IF THE TENANT TABLE HAS ShipmentId
      Dynamic SQL avoids assuming undocumented response/status column names.
   ============================================================================= */
IF OBJECT_ID(N'dbo.ue_SMK069_shipment_api_log_mst', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.ue_SMK069_shipment_api_log_mst', N'ShipmentId') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        SELECT TOP (50) *
        FROM dbo.ue_SMK069_shipment_api_log_mst
        WHERE ShipmentId IN (N''P96330'', N''P96331'', N''P96332'');';
END;

/* =============================================================================
   9. SCHEDULER TABLE METADATA / STATE, IF INSTALLED
      This confirms whether an automatic retry could still fire while we audit.
   ============================================================================= */
IF OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst', N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        SELECT
            SiteRef,
            ScheduleCode,
            ScheduleName,
            IntervalMinutes,
            MaxShipments,
            IsEnabled,
            NextRunDate,
            RunRequested,
            RunState,
            LeaseUntil,
            LastStartDate,
            LastRunDate,
            LastRunStatus,
            LastCandidates,
            LastSucceeded,
            LastFailed,
            LastExhausted,
            LastMessage
        FROM dbo.ue_SMK069_shipment_schedule_mst
        WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
        ORDER BY ScheduleCode;';
END;

/* =============================================================================
   DECISION GATE
   -------------
   Do NOT retry until all of these are true:

   A. EndpointUrl is confirmed by POS team / known-good UAT evidence.
   B. Exact Complete SP source and line 36 are captured.
   C. The nvarchar -> bigint crossing is identified and patched minimally.
   D. P96331 has a valid DOC_NO/Customer Order before it is eligible to send.
   E. Scheduler/Run Now remains held during the investigation.
   ============================================================================= */
