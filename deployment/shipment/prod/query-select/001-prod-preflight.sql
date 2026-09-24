/* SMK Query Select Execution - PROD preflight
   Pure SELECT only. No DECLARE / EXEC / GO / trailing semicolon.
*/
SELECT
    RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0)) AS SiteRef,
    CASE WHEN OBJECT_ID(N'dbo.SMK069_ShipmentAPI_mst', N'V') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ShipView,
    CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst', N'U') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ApiCfgTable,
    CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_shipment_api_log_mst', N'U') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ApiLogTable,
    CASE WHEN OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS BuildSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS PrepareSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS CompleteSp,
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.parameters
        WHERE object_id = OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp', N'P')
          AND parameter_id = 1
          AND LOWER(TYPE_NAME(user_type_id)) IN (N'nvarchar',N'varchar',N'nchar',N'char')
    ) THEN N'PASS' ELSE N'FAIL' END AS BuildDnString,
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.parameters
        WHERE object_id = OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp', N'P')
          AND parameter_id = 1
          AND LOWER(TYPE_NAME(user_type_id)) IN (N'nvarchar',N'varchar',N'nchar',N'char')
    ) THEN N'PASS' ELSE N'FAIL' END AS PrepareDnString,
    CASE WHEN CHARINDEX(N'SMK069-DOC-NONBLOCKING-R2', ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp',N'P')),N'')) > 0 THEN N'PASS' ELSE N'FAIL' END AS DocNoRule,
    CASE WHEN CHARINDEX(N'SMK069-STORE-ORDER-NONBLOCKING-R1', ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp',N'P')),N'')) > 0 THEN N'PASS' ELSE N'FAIL' END AS StoreOrderRule,
    CASE WHEN CHARINDEX(N'SMK069-PRICE-POSITIVE-R1', ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069BuildShipmentJsonSp',N'P')),N'')) > 0 THEN N'PASS' ELSE N'FAIL' END AS PriceRule,
    CASE WHEN CHARINDEX(N'SMK069-COMPLETE-DN-STRING-R1', ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp',N'P')),N'')) > 0 THEN N'PASS' ELSE N'FAIL' END AS CompleteDnRule,
    CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_shipment_retry_mst',N'U') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS RetryTable,
    CASE WHEN OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst',N'U') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ScheduleTable,
    CASE WHEN OBJECT_ID(N'dbo.SMK069GetShipmentConfigSp',N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS GetConfig,
    CASE WHEN OBJECT_ID(N'dbo.SMK069GetPendingShipmentsSp',N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS GetPending,
    CASE WHEN OBJECT_ID(N'dbo.SMK069RecordShipmentAttemptSp',N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS RecordAttempt,
    CASE WHEN OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp',N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ClaimSchedule,
    CASE WHEN OBJECT_ID(N'dbo.SMK069CompleteShipmentScheduleSp',N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS CompleteSchedule,
    CASE WHEN OBJECT_ID(N'dbo.SMK069_ShipmentSchedulerDashboard_vw',N'V') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS DashboardView,
    CASE WHEN OBJECT_ID(N'dbo.SMK069_ShipmentSchedulerQueue_vw',N'V') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS QueueView
