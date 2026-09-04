/*
    SMK069 Shipment KACS mapping verification
    Run in SMK Query Select Execution / Query Execution.
    Do not expect SELECT grids from Apply Database.
*/

DECLARE @Site SiteType;
SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
EXEC SetSiteSp @Site, NULL;

-- 1. Mapping rows for the active Site
SELECT
    SiteRef,
    SytelineCustNum,
    KacsCustCode,
    KacsStoreCode,
    IsActive
FROM dbo.ue_SMK069_shipment_customer_map_mst
WHERE SiteRef = @Site
ORDER BY SytelineCustNum;

SELECT
    SiteRef,
    SytelineWhse,
    KacsWhsCode,
    IsActive
FROM dbo.ue_SMK069_shipment_whse_map_mst
WHERE SiteRef = @Site
ORDER BY SytelineWhse;

SELECT
    SiteRef,
    SytelineUom,
    KacsUom,
    IsActive
FROM dbo.ue_SMK069_shipment_uom_map_mst
WHERE SiteRef = @Site
ORDER BY SytelineUom;

-- 2. DN22 API-ready view result
SELECT
    site_ref,
    cust_code,
    whse_code,
    doc_no,
    DN_No,
    Delivery_date,
    Store_Order_No,
    store_code,
    Vehicle_number,
    product_code,
    shipment_qty,
    UOM,
    Price,
    Batch,
    Expiry_date,
    Api_post,
    Api_post_date
FROM dbo.SMK069_ShipmentAPI_mst
WHERE site_ref = @Site
  AND DN_No = 22
ORDER BY product_code, Batch;

-- 3. Exact JSON builder result for DN22
DECLARE
    @PayloadJson NVARCHAR(MAX),
    @Success INT,
    @Infobar NVARCHAR(4000);

EXEC dbo.SMK069BuildShipmentJsonSp
    @DN_No = 22,
    @PayloadJson = @PayloadJson OUTPUT,
    @Success = @Success OUTPUT,
    @Infobar = @Infobar OUTPUT;

SELECT
    @Success AS Success,
    @Infobar AS Infobar,
    @PayloadJson AS PayloadJson;
