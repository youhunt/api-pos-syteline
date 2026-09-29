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
        N'AND ScheduleCode = @ScheduleCode',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp')), N'')
    ) > 0
    AND CHARINDEX(
        N'AND IsEnabled = 1;',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp')), N'')
    ) = 0
    THEN N'PASS' ELSE N'FAIL' END AS RequestAllowsDisabledSchedule,
    CASE WHEN CHARINDEX(
        N'RunRequested = 1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
    ) > 0
    AND CHARINDEX(
        N'ISNULL(@MasterEnabled, 0) = 1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
    ) > 0
    THEN N'PASS' ELSE N'FAIL' END AS ManualVsRecurringGate
