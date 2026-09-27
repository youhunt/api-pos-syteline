/* =============================================================================
   Canonical DEV source: dbo.ue_SMK069_pos_sales_inbound_mapping_view
   Captured from working DEV tenant definition supplied by user.
   Scope: CSV / POS inbound -> Blanket Customer Order
   Captured: 2026-09-28

   DEV definition SHA-256:
   E1D32D405FE78D96259224E0D2EF78763E4216189A5F2222EE627228C75D1B0B

   Notes:
   - Peak/Normal mapping is selected by itemcust.Uf_SMK069_is_peak_season.
   - ValidationStatus is V/N based on converted base quantity.
   - Active site is constrained by CONTEXT_INFO().
   ============================================================================= */

CREATE OR ALTER VIEW dbo.ue_SMK069_pos_sales_inbound_mapping_view
AS
SELECT
    i.inbound_id,
    i.source_system,
    i.batch_id,
    i.row_no,
    i.raw_json,
    i.SiteRef,
    c.cust_num,
    c.cust_seq,
    i.cust_po,
    i.order_date,
    i.co_num,
    i.co_line,
    it.item AS item,
    CAST
    (
        ISNULL
        (
            dbo.SMK030_UomConvQty2
            (
                i.qty_ordered,
                ISNULL(dbo.Getumcf(i.u_m, ic.item, '', ''), 1),
                'To Base'
            ),
            0
        ) AS decimal(23,5)
    ) AS qty_ordered,
    (
        SELECT TOP 1 p.cont_price
        FROM itemcustprice p
        JOIN itemcust ci
          ON p.item = ci.item
         AND p.cust_num = ci.cust_num
        WHERE i.order_date >= p.effect_date
          AND ci.cust_item = i.item
          AND ci.u_m = it.u_m
          AND ci.cust_num = c.cust_num
          AND ci.Uf_SMK069_is_peak_season = i.is_peak_season
        ORDER BY p.effect_date DESC
    ) AS unit_price,
    IIF(i.whse = 'P963', 'PLG', 'MAIN') AS whse,
    DATEADD(dd, ISNULL(ic.due_period, 0), i.order_date) AS due_date,
    it.u_m AS u_m,
    cs.terms_code,
    cs.tax_code1,
    i.exch_rate,
    i.inbound_status,
    i.validation_msg,
    i.received_date,
    i.validated_date,
    i.transferred_date,
    i.created_by,
    i.updated_by,
    i.is_peak_season,
    CASE
        WHEN
            CAST
            (
                ISNULL
                (
                    dbo.SMK030_UomConvQty2
                    (
                        i.qty_ordered,
                        ISNULL(dbo.Getumcf(i.u_m, ic.item, '', ''), 1),
                        'To Base'
                    ),
                    0
                ) AS decimal(23,5)
            )
            <>
            FLOOR
            (
                CAST
                (
                    ISNULL
                    (
                        dbo.SMK030_UomConvQty2
                        (
                            i.qty_ordered,
                            ISNULL(dbo.Getumcf(i.u_m, ic.item, '', ''), 1),
                            'To Base'
                        ),
                        0
                    ) AS decimal(23,5)
                )
            )
        THEN 'N'
        ELSE 'V'
    END AS ValidationStatus
FROM ue_SMK069_pos_sales_inbound_mst i
JOIN custaddr c
  ON i.cust_num = LEFT(c.name, 4)
 AND c.cust_num LIKE 'PH%'
 AND c.cust_seq <> 0
LEFT JOIN customer cs
  ON cs.cust_num = c.cust_num
 AND cs.cust_seq = 0
JOIN itemcust ic
  ON ic.cust_item = i.item
 AND ic.cust_num = c.cust_num
 AND ic.Uf_SMK069_is_peak_season = i.is_peak_season
JOIN item it
  ON it.item = ic.item
WHERE i.SiteRef = CAST(CONTEXT_INFO() AS NVARCHAR(8));
