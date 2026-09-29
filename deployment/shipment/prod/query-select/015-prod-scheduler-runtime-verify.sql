/* SMK Query Select Execution - PROD scheduler SQL runtime verification
   Exact current TRN baseline: verify runtime objects only.
   Patch 19 Run Once bypass is NOT part of the verified TRN baseline.
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
    CASE WHEN OBJECT_ID(N'dbo.SMK069_ShipmentSchedulerQueue_vw', N'V') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS QueueView
