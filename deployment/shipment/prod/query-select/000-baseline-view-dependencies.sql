/* SMK Query Select Execution - PROD baseline dependency preflight
   Pure SELECT only. No trailing semicolon.
*/
SELECT
    CASE WHEN OBJECT_ID(N'dbo.shipment_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ShipmentMst,
    CASE WHEN OBJECT_ID(N'dbo.shipment_line_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ShipmentLine,
    CASE WHEN OBJECT_ID(N'dbo.shipment_seq_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ShipmentSeq,
    CASE WHEN OBJECT_ID(N'dbo.coitem_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS Coitem,
    CASE WHEN OBJECT_ID(N'dbo.co_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS CoMst,
    CASE WHEN OBJECT_ID(N'dbo.customer_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS Customer,
    CASE WHEN OBJECT_ID(N'dbo.custaddr_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS Custaddr,
    CASE WHEN OBJECT_ID(N'dbo.lot_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS LotMst,
    CASE WHEN OBJECT_ID(N'dbo.itemcust_mst') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS Itemcust,
    CASE WHEN OBJECT_ID(N'dbo.UserDefinedTypes') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS UDTTable,
    CASE WHEN OBJECT_ID(N'dbo.UserDefinedTypeValues') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS UDTValues,
    CASE WHEN OBJECT_ID(N'dbo.SMK030_UomConvQty2') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS UomConvFn,
    CASE WHEN OBJECT_ID(N'dbo.Getumcf') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS GetumcfFn,
    CASE WHEN COL_LENGTH(N'dbo.shipment_mst', N'SMK069_Uf_API_post') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ApiPostCol,
    CASE WHEN COL_LENGTH(N'dbo.shipment_mst', N'SMK069_Uf_API_post_date') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS ApiPostDateCol,
    CASE WHEN COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_pos_um') IS NOT NULL THEN N'PASS' ELSE N'FAIL' END AS PosUomCol,
    CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.UserDefinedTypes AS u
        WHERE u.name = N'SMK069_MappingUOM'
    ) THEN N'PASS' ELSE N'FAIL' END AS UomMappingType
