CREATE   VIEW dbo.SMK069_ShipmentAPI_mst
AS

SELECT
    sh.site_ref AS site_ref,

    sh.cust_num AS cust_code,

    -- Temporary, nanti mapping ke POS warehouse code
    IIF(sh.whse = 'PLG', 'P963', 'R975') AS whse_code,

    co.cust_po AS doc_no,

    CAST(CONCAT(IIF(sh.whse = 'PLG', 'P963', 'R975'), sh.shipment_id) AS nvarchar(10) )AS DN_No,

    sh.ship_date AS Delivery_date,

    ISNULL(CAST(SUBSTRING(co.cust_po, CHARINDEX('-', co.cust_po) + 1, LEN(co.cust_po)) AS nvarchar(20)),'') AS Store_Order_No,
	
    left(c.name,4)  AS store_code,

    sh.veh_num AS Vehicle_number,

    ic.cust_item AS product_code,

    --shipseq.qty_shipped AS shipment_qty,

	SUM(CAST(ISNULL(dbo.SMK030_UomConvQty2( shipseq.qty_shipped, ISNULL(dbo.Getumcf(ic.Uf_SMK069_pos_um, coi.item, '', ''), 1), 'From Base') , 0) AS decimal(23,5))) AS shipment_qty,
    
	CAST(v.description AS int)  AS UOM,

    --coi.price AS Price,
	CAST(ISNULL(dbo.SMK030_UomConvQty2( coi.price, ISNULL(dbo.Getumcf(ic.Uf_SMK069_pos_um, coi.item, '', ''), 1), 'To Base') , 0) AS decimal(23,5)) AS Price,

    --shipseq.lot AS Batch,
    NULL AS Batch,

    --lot.exp_date AS Expiry_date,
    NULL AS Expiry_date,

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
   
LEFT JOIN dbo.custaddr_mst c
	ON c.cust_num = sh.cust_num
	AND c.cust_seq = sh.cust_seq

LEFT JOIN dbo.shipment_seq_mst shipseq
    ON shipseq.shipment_id = shl.shipment_id
   AND shipseq.shipment_line = shl.shipment_line
   AND shipseq.site_ref = sh.site_ref

LEFT JOIN dbo.lot_mst lot
    ON lot.lot = shipseq.lot
   AND lot.item = coi.item
   AND lot.site_ref = sh.site_ref

LEFT JOIN itemcust_mst ic 
	ON ic.cust_num = sh.cust_num
	AND ic.item = coi.item

LEFT JOIN (SELECT v.value, v.description
			FROM UserDefinedTypes u
			JOIN UserDefinedTypeValues v on v.Typename = u.name
			WHERE u.name = 'SMK069_MappingUOM'
		) v 
	ON v.value = ic.Uf_SMK069_pos_um

WHERE c.cust_num LIKE 'PH%'
AND ISNULL(sh.SMK069_Uf_API_post, 0) = 0
--AND sh.cust_seq = '164'

AND sh.site_ref = CAST(CONTEXT_INFO() AS NVARCHAR(8))

GROUP BY
    sh.site_ref,
    sh.cust_num,
    IIF(sh.whse = 'PLG', 'P963', 'R975'),
    co.cust_po,
    CAST( CONCAT(IIF(sh.whse = 'PLG', 'P963', 'R975'), sh.shipment_id  ) AS nvarchar(10)),
    sh.ship_date,
    ISNULL(CAST( SUBSTRING(co.cust_po, CHARINDEX('-', co.cust_po) + 1, LEN(co.cust_po)) AS nvarchar(20) ), '' ),
    LEFT(c.name, 4),
    sh.veh_num,
    ic.cust_item,
    CAST(v.description AS int),
    CAST( ISNULL( dbo.SMK030_UomConvQty2(coi.price, ISNULL(dbo.Getumcf(ic.Uf_SMK069_pos_um, coi.item, '', ''), 1),'To Base' ), 0) AS decimal(23,5)
    ),
    ISNULL(sh.SMK069_Uf_API_post, 0),
    sh.SMK069_Uf_API_post_date
