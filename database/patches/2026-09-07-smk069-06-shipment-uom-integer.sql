/* =============================================================================
   *** DITARIK - JANGAN DIJALANKAN ***
   -----------------------------------------------------------------------------
   Ditarik 7 September 2026.

   Patch ini dibuat ketika UOM masih keluar sebagai kode alfabet SyteLine dan
   DN_No masih BIGINT. Keduanya sudah diselesaikan langsung di
   SMK069_ShipmentAPI_mst: view sekarang mengeluarkan UOM sebagai angka dan
   DN_No sebagai string berprefiks (P96325).

   Menjalankan patch ini akan menambahkan JOIN ke tabel pemetaan yang tidak
   diperlukan, dan mengembalikan parameter @DN_No ke BIGINT - yang akan merusak
   rantai yang sudah berjalan.

   Disimpan sebagai catatan arah yang sempat ditempuh, bukan sebagai patch aktif.
   Lihat docs/28 untuk keadaan sebenarnya.
   ============================================================================= */

/* =============================================================================
   SMK069 - Shipment payload UOM as integer, Patch 06
   -----------------------------------------------------------------------------
   Object   : dbo.SMK069BuildShipmentJsonSp                  (PATCHED)
   Date     : 2026-09-07
   Design   : docs/28-shipment-infor-endpoint-and-uom.md
   Depends  : Patch 05 (dbo.ue_SMK069_pos_uom_map_mst)

   >>> BEFORE APPLY DATABASE <<<
   Capture the current definition first, both as a rollback and because the
   repository copy has been out of sync with the tenant since August:

       SELECT definition FROM sys.sql_modules
       WHERE object_id = OBJECT_ID('dbo.SMK069BuildShipmentJsonSp');

   Signature is unchanged: @DN_No, @PayloadJson OUT, @Success OUT, @Infobar OUT.
   No IDO method metadata change.

   WHAT CHANGED
   ------------
   1. UOM is emitted as a JSON NUMBER, resolved through
      ue_SMK069_pos_uom_map_mst. Previously the SyteLine alphabetic unit went
      out verbatim:

          d.UOM AS [UOM]        ->  "UOM": "TRY"
          m.pos_uom_code        ->  "UOM": 3

   2. A new validation gate refuses to build a payload when any line's u_m is
      not mapped, and names the offending values. Sending a guessed UOM code
      would be accepted by POS against the wrong unit, and the mistake would
      surface later in stock rather than here.

   REVISION 2 - 7 Sep 2026, implicit conversion fix
   -------------------------------------------------
   Revision 1 failed at runtime with:

       Error converting data type nvarchar to bigint.:dbo.SMK069BuildShipmentJsonSp:33

   @DN_No is BIGINT while SMK069_ShipmentAPI_mst.DN_No carries shipment_id as
   nvarchar. Comparing them makes SQL Server convert the nvarchar side to bigint
   for every row the predicate touches, not only the matching one, so a single
   non-numeric shipment_id anywhere in the view fails the whole statement.

   The original procedure had the same defect and survived only because the plan
   happened to filter before converting. Adding the UOM join changed the plan and
   exposed it. implementation/22 section 10 already worked around the same thing
   with CONVERT(NVARCHAR(50), DN_No) in a verification query; the procedure was
   never given the same treatment.

   Every DN_No comparison is now explicit on the string side. This costs index
   seekability on DN_No, which is acceptable: the predicate is already bounded by
   site_ref and the view returns few rows per shipment.

   NOTE FOR THE DN_NO UNIQUENESS QUESTION (docs/28 section 6)
   If POS requires a prefixed DN such as SL<site><shipment_id>, the @DN_No BIGINT
   parameter blocks it outright. Changing that parameter's type is an IDO method
   metadata change and belongs in its own patch, not this one.

   WHAT DELIBERATELY DID NOT CHANGE
   --------------------------------
   SHIPMENT_QTY and PRICE keep CONVERT(DECIMAL(19,8), ...), so they still go out
   as 390.00000000 rather than 390. A UAT payload carrying exactly that shape
   was answered with 1010 "data is exist" on 7 Sep, which is a duplicate-key
   rejection and therefore proof the payload passed field validation. Trailing
   decimals are accepted; there is no reason to touch them.

   For the same reason CUST_CODE, WHS_CODE, STORE_CODE and DOC_NO are left as
   they are. That same accepted payload carried the SyteLine values PHD0001,
   P963, DEV4 and R260902058. The earlier theory that these needed translating
   into POS-side codes was wrong.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069BuildShipmentJsonSp
(
    @DN_No       BIGINT,
    @PayloadJson NVARCHAR(MAX) OUTPUT,
    @Success     INT OUTPUT,
    @Infobar     NVARCHAR(4000) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- SITE CONTEXT
    ------------------------------------------------------------
    DECLARE @Site SiteType

    SELECT @Site =
        RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))

    EXEC SetSiteSp @Site, NULL

    ------------------------------------------------------------
    -- INITIAL OUTPUT
    ------------------------------------------------------------
    SET @PayloadJson = NULL;
    SET @Success     = 0;
    SET @Infobar     = NULL;

    ------------------------------------------------------------
    -- Shipment harus ada pada Site aktif dan masih pending
    ------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), DN_No)))
              = CONVERT(NVARCHAR(50), @DN_No)
          AND ISNULL(Api_post, 0) = 0
    )
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' tidak ditemukan pada Site ',
                @Site,
                ' atau sudah diposting.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- Harus mempunyai qty > 0
    ------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), DN_No)))
              = CONVERT(NVARCHAR(50), @DN_No)
          AND ISNULL(Api_post, 0) = 0
          AND ISNULL(shipment_qty, 0) > 0
    )
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' tidak mempunyai shipment qty > 0 pada Site ',
                @Site,
                '.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- Satu DN hanya boleh mempunyai satu DOC_NO
    ------------------------------------------------------------
    DECLARE @DocCount INT;

    SELECT
        @DocCount =
            COUNT(
                DISTINCT NULLIF(
                    LTRIM(RTRIM(doc_no)),
                    ''
                )
            )
    FROM dbo.SMK069_ShipmentAPI_mst
    WHERE site_ref = @Site
      AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), DN_No)))
          = CONVERT(NVARCHAR(50), @DN_No)
      AND ISNULL(Api_post, 0) = 0
      AND ISNULL(shipment_qty, 0) > 0;

    IF ISNULL(@DocCount, 0) = 0
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' tidak mempunyai DOC_NO/Customer Order.'
            );

        RETURN 0;
    END;

    IF @DocCount > 1
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' mempunyai lebih dari satu DOC_NO pada Site ',
                @Site,
                '. Payload tidak dibuat.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- HEADER
    ------------------------------------------------------------
    DECLARE
        @CustCode      NVARCHAR(50),
        @WhseCode      NVARCHAR(50),
        @DocNo         NVARCHAR(50),
        @DeliveryDate  DATETIME,
        @StoreOrderNo  NVARCHAR(100),
        @StoreCode     NVARCHAR(100),
        @VehicleNumber NVARCHAR(100);

    SELECT TOP (1)
        @CustCode      = cust_code,
        @WhseCode      = whse_code,
        @DocNo         = doc_no,
        @DeliveryDate  = Delivery_date,
        @StoreOrderNo  = Store_Order_No,
        @StoreCode     = store_code,
        @VehicleNumber = Vehicle_number
    FROM dbo.SMK069_ShipmentAPI_mst
    WHERE site_ref = @Site
      AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), DN_No)))
          = CONVERT(NVARCHAR(50), @DN_No)
      AND ISNULL(Api_post, 0) = 0
      AND ISNULL(shipment_qty, 0) > 0;

    ------------------------------------------------------------
    -- HEADER VALIDATION
    ------------------------------------------------------------
    IF NULLIF(LTRIM(RTRIM(ISNULL(@CustCode, ''))), '') IS NULL
    BEGIN
        SET @Infobar = 'CUST_CODE kosong.';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@WhseCode, ''))), '') IS NULL
    BEGIN
        SET @Infobar = 'WHS_CODE kosong.';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@DocNo, ''))), '') IS NULL
    BEGIN
        SET @Infobar = 'DOC_NO kosong.';
        RETURN 0;
    END;

    IF @DeliveryDate IS NULL
    BEGIN
        SET @Infobar = 'DELIVERY_DATE kosong.';
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreOrderNo, ''))), '') IS NULL
    BEGIN
        SET @Infobar = 'STORE_ORDER_NO kosong.';
        RETURN 0;
    END;

    ------------------------------------------------------------
    -- PRODUCT VALIDATION
    ------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), DN_No)))
              = CONVERT(NVARCHAR(50), @DN_No)
          AND ISNULL(Api_post, 0) = 0
          AND ISNULL(shipment_qty, 0) > 0
          AND NULLIF(
                LTRIM(RTRIM(ISNULL(product_code, ''))),
                ''
              ) IS NULL
    )
    BEGIN
        SET @Infobar =
            'Terdapat detail shipment dengan PRODUCT_CODE kosong.';

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- UOM VALIDATION  (BARU - Patch 06)
    -- POS menuntut UOM berupa angka. Tidak boleh menebak kodenya.
    ------------------------------------------------------------
    DECLARE @UnmappedUom NVARCHAR(1000);

    SELECT @UnmappedUom =
        STUFF
        (
            (
                SELECT DISTINCT
                    ', ' + COALESCE(
                        NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(20), d.UOM))), ''),
                        '<kosong>'
                    )
                FROM dbo.SMK069_ShipmentAPI_mst AS d
                WHERE d.site_ref = @Site
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), d.DN_No)))
                      = CONVERT(NVARCHAR(50), @DN_No)
                  AND ISNULL(d.Api_post, 0) = 0
                  AND ISNULL(d.shipment_qty, 0) > 0
                  AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.ue_SMK069_pos_uom_map_mst AS m
                      WHERE m.SiteRef = d.site_ref
                        AND m.is_active = 1
                        AND UPPER(LTRIM(RTRIM(m.syteline_um)))
                                COLLATE DATABASE_DEFAULT
                            = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), d.UOM))))
                                COLLATE DATABASE_DEFAULT
                  )
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'),
            1, 2, ''
        );

    IF NULLIF(@UnmappedUom, '') IS NOT NULL
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ': U/M berikut belum dipetakan ke kode UOM POS: ',
                @UnmappedUom,
                '. Lengkapi dbo.ue_SMK069_pos_uom_map_mst untuk Site ',
                @Site,
                ' sebelum mengirim. Kode UOM tidak boleh ditebak.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- BUILD JSON
    ------------------------------------------------------------
    SELECT @PayloadJson =
    (
        SELECT
            @CustCode AS [CUST_CODE],
            @WhseCode AS [WHS_CODE],
            @DocNo AS [DOC_NO],
            CONVERT(VARCHAR(30), @DN_No) AS [DN_NO],

            CONVERT(CHAR(10), @DeliveryDate, 23)
                AS [DELIVERY_DATE],

            @StoreOrderNo AS [STORE_ORDER_NO],

            ISNULL(@StoreCode, '')
                AS [STORE_CODE],

            ISNULL(@VehicleNumber, '')
                AS [VEHICLE_NUMBER],

            JSON_QUERY
            (
                (
                    SELECT
                        d.product_code AS [PRODUCT_CODE],

                        CONVERT(
                            DECIMAL(19,8),
                            d.shipment_qty
                        ) AS [SHIPMENT_QTY],

                        /* Patch 06: angka, bukan kode alfabet SyteLine. */
                        m.pos_uom_code AS [UOM],

                        CONVERT(
                            DECIMAL(19,8),
                            d.Price
                        ) AS [PRICE],

                        d.Batch AS [BATCH],

                        CASE
                            WHEN d.Expiry_date IS NULL
                                THEN NULL
                            ELSE
                                CONVERT(
                                    CHAR(10),
                                    d.Expiry_date,
                                    23
                                )
                        END AS [EXPIRY_DATE]

                    FROM dbo.SMK069_ShipmentAPI_mst d
                    INNER JOIN dbo.ue_SMK069_pos_uom_map_mst m
                        ON  m.SiteRef = d.site_ref
                        AND m.is_active = 1
                        AND UPPER(LTRIM(RTRIM(m.syteline_um)))
                                COLLATE DATABASE_DEFAULT
                            = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), d.UOM))))
                                COLLATE DATABASE_DEFAULT
                    WHERE d.site_ref = @Site
                      AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), d.DN_No)))
                      = CONVERT(NVARCHAR(50), @DN_No)
                      AND ISNULL(d.Api_post, 0) = 0
                      AND ISNULL(d.shipment_qty, 0) > 0

                    ORDER BY
                        d.product_code,
                        d.Batch

                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )
            ) AS [DETAIL]

        FOR JSON PATH,
            WITHOUT_ARRAY_WRAPPER,
            INCLUDE_NULL_VALUES
    );

    ------------------------------------------------------------
    -- SUCCESS
    ------------------------------------------------------------
    SET @Success = 1;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@StoreCode, ''))), '') IS NULL
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' berhasil dibuat menjadi JSON untuk Site ',
                @Site,
                '. WARNING: STORE_CODE masih kosong.'
            );
    END
    ELSE
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @DN_No),
                ' berhasil dibuat menjadi JSON untuk Site ',
                @Site,
                '.'
            );
    END;

    RETURN 0;
END;
GO
