CREATE OR ALTER VIEW dbo.SMK069_ShipmentAPI_mst
AS

SELECT
    sh.site_ref AS site_ref,

    NULLIF(LTRIM(RTRIM(cmap.KacsCustCode)), '') AS cust_code,

    NULLIF(LTRIM(RTRIM(wmap.KacsWhsCode)), '') AS whse_code,

    co.co_num AS doc_no,

    sh.shipment_id AS DN_No,

    sh.ship_date AS Delivery_date,

    co.cust_po AS Store_Order_No,

    NULLIF(LTRIM(RTRIM(cmap.KacsStoreCode)), '') AS store_code,

    sh.veh_num AS Vehicle_number,

    coi.item AS product_code,

    shipseq.qty_shipped AS shipment_qty,

    -- KACS contract uses numeric UOM in JSON (example: 1).
    -- Mapping is Shipment-specific; do not reuse POS inbound/CO mapping.
    umap.KacsUom AS UOM,

    coi.price AS Price,

    shipseq.lot AS Batch,

    lot.exp_date AS Expiry_date,

    ISNULL(sh.SMK069_Uf_API_post, 0) AS Api_post,

    sh.SMK069_Uf_API_post_date AS Api_post_date

FROM dbo.shipment_mst sh

LEFT JOIN dbo.shipment_line_mst shl
    ON shl.shipment_id = sh.shipment_id
   AND shl.site_ref = sh.site_ref

LEFT JOIN dbo.coitem_mst coi
    ON coi.co_num = shl.ref_num
   AND coi.co_line = shl.ref_line_suf
   AND coi.co_release = shl.ref_release
   AND coi.site_ref = sh.site_ref

LEFT JOIN dbo.co_mst co
    ON co.co_num = coi.co_num
   AND co.site_ref = coi.site_ref

LEFT JOIN dbo.shipment_seq_mst shipseq
    ON shipseq.shipment_id = shl.shipment_id
   AND shipseq.shipment_line = shl.shipment_line
   AND shipseq.site_ref = sh.site_ref

LEFT JOIN dbo.lot_mst lot
    ON lot.lot = shipseq.lot
   AND lot.item = coi.item
   AND lot.site_ref = sh.site_ref

LEFT JOIN dbo.ue_SMK069_shipment_customer_map_mst cmap
    ON cmap.SiteRef = sh.site_ref
   AND cmap.SytelineCustNum = sh.cust_num
   AND cmap.IsActive = 1

LEFT JOIN dbo.ue_SMK069_shipment_whse_map_mst wmap
    ON wmap.SiteRef = sh.site_ref
   AND wmap.SytelineWhse = sh.whse
   AND wmap.IsActive = 1

LEFT JOIN dbo.ue_SMK069_shipment_uom_map_mst umap
    ON umap.SiteRef = sh.site_ref
   AND umap.SytelineUom = coi.u_m
   AND umap.IsActive = 1;
