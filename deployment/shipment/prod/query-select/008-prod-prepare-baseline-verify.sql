/* SMK Query Select Execution - PROD PrepareShipment baseline verification
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    CASE WHEN OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp', N'P') IS NOT NULL
         THEN N'PASS' ELSE N'FAIL' END AS PrepareSp,
    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.parameters
        WHERE object_id = OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp')
          AND name = N'@DN_No'
          AND TYPE_NAME(user_type_id) = N'nvarchar'
          AND max_length = 80
    ) THEN N'PASS' ELSE N'FAIL' END AS DnParamNvarchar40,
    CASE WHEN CHARINDEX(
        N'SMK069BuildShipmentJsonSp',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS CallsBuildSp,
    CASE WHEN CHARINDEX(
        N'ue_SMK069_shipment_api_log_mst',
        ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp')), N'')
    ) > 0 THEN N'PASS' ELSE N'FAIL' END AS UsesApiLog,
    LEN(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069PrepareShipmentSendSp'))) AS DefinitionLength
