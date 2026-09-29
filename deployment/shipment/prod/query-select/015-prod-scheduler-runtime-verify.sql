/* SMK Query Select Execution - PROD scheduler SQL runtime verification
   Run after 020-022, 032-038, 040-041 and 070.
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    CASE WHEN OBJECT_ID(N'dbo.SMK069GetShipmentConfigSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS GetConfigSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069GetPendingShipmentsSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS GetPendingSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069RecordShipmentAttemptSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS RecordAttemptSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069GetShipmentSchedulerDashboardSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS DashboardSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069SaveShipmentScheduleSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS SaveScheduleSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069SetShipmentSchedulerEnabledSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS SetSchedulerSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS RunNowSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069ResetShipmentRetrySp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ResetRetrySp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ClaimScheduleSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069CompleteShipmentScheduleSp', N'P') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS CompleteScheduleSp,
    CASE WHEN OBJECT_ID(N'dbo.SMK069_ShipmentSchedulerDashboard_vw', N'V') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS DashboardView,
    CASE WHEN OBJECT_ID(N'dbo.SMK069_ShipmentSchedulerQueue_vw', N'V') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS QueueView,
    CASE WHEN CHARINDEX(N'SMK069-RUNONCE-BYPASS-MASTER-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp')), N'')) > 0
        THEN N'PASS' ELSE N'FAIL' END AS RunOnceBypass,
    CASE WHEN CHARINDEX(N'SMK069-RUNONCE-CLAIM-MANUAL-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')) > 0
        THEN N'PASS' ELSE N'FAIL' END AS ManualClaimBypass
