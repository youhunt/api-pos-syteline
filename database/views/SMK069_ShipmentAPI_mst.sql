CREATE   VIEW dbo.SMK069_ShipmentAPI_mst
AS

SELECT
    sh.site_ref AS site_ref,

    sh.cust_num AS cust_code,

    -- Temporary, nanti mapping ke POS warehouse code
    sh.whse AS whse_code,

    co.co_num AS doc_no,

    sh.shipment_id AS DN_No,

    sh.ship_date AS Delivery_date,

    co.cust_po AS Store_Order_No,

    cst.cust_type AS store_code,

    sh.veh_num AS Vehicle_number,

    coi.item AS product_code,

    shipseq.qty_shipped AS shipment_qty,

    coi.u_m AS UOM,

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

LEFT JOIN dbo.customer_mst cst
    ON cst.cust_num = sh.cust_num
   AND cst.cust_seq = 0
   AND cst.site_ref = sh.site_ref

LEFT JOIN dbo.shipment_seq_mst shipseq
    ON shipseq.shipment_id = shl.shipment_id
   AND shipseq.shipment_line = shl.shipment_line
   AND shipseq.site_ref = sh.site_ref

LEFT JOIN dbo.lot_mst lot
    ON lot.lot = shipseq.lot
   AND lot.item = coi.item
   AND lot.site_ref = sh.site_ref;
