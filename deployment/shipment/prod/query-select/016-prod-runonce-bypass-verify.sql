/* OPTIONAL Patch 19 verifier ONLY.
   NOT a current TRN -> PROD baseline readiness gate.
   Current verified TRN baseline does not contain these Patch 19 markers.
   Run this only when Patch 19 / 070 is intentionally being tested.
*/
/* SMK Query Select Execution - PROD Patch 19 / Run Once verification
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    CASE WHEN CHARINDEX(
        N'SMK069-RUNONCE-BYPASS-MASTER-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS RunOnceBypass,
    CASE WHEN CHARINDEX(
        N'SMK069-RUNONCE-CLAIM-MANUAL-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS ManualClaimBypass,
    CASE WHEN CHARINDEX(
        N'AND (IsEnabled = 1 OR RunRequested = 1)',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS DisabledScheduleManualAllowed,
    CASE WHEN CHARINDEX(
        N'AND (ISNULL(@MasterEnabled, 0) = 1 OR RunRequested = 1)',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS MasterOffManualOnly
