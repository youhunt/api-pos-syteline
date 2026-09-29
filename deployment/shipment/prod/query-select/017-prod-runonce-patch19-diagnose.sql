/* SMK Query Select Execution - diagnose PROD Patch 19 / 070
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    LEN(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp'))) AS RequestDefLen,
    CHARINDEX(
        N'Master Shipment Scheduler masih OFF. Aktifkan master switch lebih dulu.',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp')), N'')
    ) AS RequestMasterMsgPos,
    CHARINDEX(
        N'RETURN 16;',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp')), N''),
        CHARINDEX(
            N'Master Shipment Scheduler masih OFF. Aktifkan master switch lebih dulu.',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp')), N'')
        )
    ) AS RequestReturnPos,
    LEN(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp'))) AS ClaimDefLen,
    CHARINDEX(
        N'Master Shipment Scheduler OFF; tidak ada schedule yang diklaim.',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
    ) AS ClaimMasterMsgPos,
    CHARINDEX(
        N'RETURN 0;',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N''),
        CHARINDEX(
            N'Master Shipment Scheduler OFF; tidak ada schedule yang diklaim.',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
        )
    ) AS ClaimReturnPos,
    CHARINDEX(
        N'AND IsEnabled = 1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
    ) AS IsEnabledPredicatePos,
    CHARINDEX(
        N'SMK069-RUNONCE-BYPASS-MASTER-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RequestShipmentRunNowSp')), N'')
    ) AS RequestMarkerPos,
    CHARINDEX(
        N'SMK069-RUNONCE-CLAIM-MANUAL-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ClaimDueShipmentScheduleSp')), N'')
    ) AS ClaimMarkerPos
