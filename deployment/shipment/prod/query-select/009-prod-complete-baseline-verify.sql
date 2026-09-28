/* SMK Query Select Execution - PROD CompleteShipment baseline verification
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    CASE WHEN OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P') IS NOT NULL
         THEN N'PASS' ELSE N'FAIL' END AS CompleteSp,

    CASE WHEN CHARINDEX(
        N'SMK069-COMPLETE-DN-STRING-R1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS DnStringMarker,

    CASE WHEN CHARINDEX(
        N'@ShipmentDn NVARCHAR(40)',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS ShipmentDnNvarchar40,

    CASE WHEN CHARINDEX(
        N'@ShipmentId = ShipmentId',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp')), N'')
    ) = 0 THEN N'PASS' ELSE N'FAIL' END AS OldImplicitConvertRemoved,

    CASE WHEN
        CHARINDEX(N'''P963''', ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp')), N'')) > 0
        AND CHARINDEX(N'''R975''', ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp')), N'')) > 0
        AND CHARINDEX(N'sh.shipment_id', ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp')), N'')) > 0
        THEN N'PASS' ELSE N'FAIL' END AS PrefixedDnMapping,

    CASE WHEN CHARINDEX(
        N'SMK069_Uf_api_post = 1',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS SuccessUpdatesApiPost,

    LEN(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp'))) AS DefinitionLength
