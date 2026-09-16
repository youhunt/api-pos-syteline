/* =============================================================================
   Canonical source: dbo.SMK069ProcessCustomerOrderSp
   -----------------------------------------------------------------------------
   Scope    : CSV / POS inbound -> Blanket Customer Order
   Tenant   : LENSA_SL_CSI_BAK / DEV

   FINAL BUSINESS RULES - 16 Sep 2026
   ----------------------------------
   - cust_po is the canonical business linkage.
   - @SourceCoNum is kept only as a compatibility parameter name. New callers
     pass cust_po; legacy callers may still pass the old transient R... key.
   - New SyteLine CO format = P + YYMMDD + 3-digit daily running.
     Example: P260916001.
   - After success, ue_SMK069_temp_sales_mst.co_num = actual SyteLine CO number.
   - co_mst.type = B and consolidate = 1.
   - coitem_mst.stat = O, consolidate = 1, release_date = order_date.
   - co_bln_mst is created for every line, stat = O, allow_on_pick_list = 0.
   - Idempotency is customer + business cust_po.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp
    @SiteRef       SiteType,
    @SourceCoNum   NVARCHAR(100), -- compatibility name; pass cust_po for new calls
    @CustSeq       CustSeqType = 0,
    @ProcessedBy   UsernameType = NULL,
    @CreatedCoNum  CoNumType OUTPUT,
    @Success       ListYesNoType OUTPUT,
    @Infobar       InfobarType OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CreatedCoNum = NULL;
    SET @Success = 0;
    SET @Infobar = NULL;

    DECLARE
        @CustNum                   CustNumType,
        @CustPo                    NVARCHAR(100),
        @OrderDate                 DateType,
        @Whse                      WhseType,
        @StageTermsCode            TermsCodeType,
        @StageTaxCode              TaxCodeType,
        @TermsCode                 TermsCodeType,
        @TaxCode                   TaxCodeType,
        @CurrCode                  CurrCodeType,
        @Contact                   ContactType,
        @Phone                     PhoneType,
        @EndUserType               EndUserTypeType,
        @IncludeTaxInPrice         ListYesNoType,
        @HeaderCost                AmountType,
        @HeaderMatlCost            AmountType,
        @HeaderPrice               AmountType,
        @KeyPrefix                 GenericKeyType,
        @KeyID                     BIGINT,
        @NumberLength              INT,
        @MaxKeyID                  BIGINT,
        @LineCount                 INT,
        @ExistingLineCount         INT,
        @ExistingBlanketLineCount  INT,
        @ExistingCoNum             CoNumType,
        @BadItem                   ItemType,
        @LockResult                INT,
        @LockResource              NVARCHAR(255),
        @ErrorMessage              NVARCHAR(4000),
        @ThrowMessage              NVARCHAR(2048);

    SET @SiteRef = LTRIM(RTRIM(@SiteRef));
    SET @SourceCoNum = LTRIM(RTRIM(@SourceCoNum));
    SET @ProcessedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ProcessedBy)), N''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        /* =============================================================
           1. Resolve canonical business key = cust_po
           ============================================================= */
        IF NULLIF(@SiteRef, N'') IS NULL
            THROW 50001, N'SiteRef wajib diisi.', 1;

        IF NULLIF(@SourceCoNum, N'') IS NULL
            THROW 50002, N'Cust PO wajib diisi.', 1;

        /*
           New callers pass cust_po. Legacy compatibility: an old R... co_num
           can still resolve the same staging order once, then all downstream
           processing uses cust_po only.
        */
        SELECT TOP (1)
            @CustPo = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po)))
        FROM dbo.ue_SMK069_temp_sales_mst AS t WITH (UPDLOCK, HOLDLOCK)
        WHERE t.SiteRef = @SiteRef
          AND
          (
              LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) = @SourceCoNum
              OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.co_num))) = @SourceCoNum
          )
        ORDER BY
            CASE
                WHEN LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) = @SourceCoNum THEN 0
                ELSE 1
            END,
            t.co_line;

        IF NULLIF(@CustPo, N'') IS NULL
            THROW 50003, N'Data staging untuk Cust PO tersebut tidak ditemukan.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst WITH (UPDLOCK, HOLDLOCK)
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND process_status = N'C'
        )
            THROW 50004, N'Order staging berstatus Cancelled dan tidak dapat diproses.', 1;

        SELECT
            @LineCount      = COUNT(*),
            @CustNum        = MIN(LTRIM(RTRIM(cust_num))),
            @OrderDate      = MIN(order_date),
            @Whse           = MIN(LTRIM(RTRIM(whse))),
            @StageTermsCode = MIN(NULLIF(LTRIM(RTRIM(terms_code)), N'')),
            @StageTaxCode   = MIN(NULLIF(LTRIM(RTRIM(tax_code1)), N''))
        FROM dbo.ue_SMK069_temp_sales_mst WITH (UPDLOCK, HOLDLOCK)
        WHERE SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo;

        IF ISNULL(@LineCount, 0) = 0
            THROW 50005, N'Order staging tidak memiliki line.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND NULLIF(LTRIM(RTRIM(cust_num)), N'') IS NULL
        )
            THROW 50006, N'cust_num wajib diisi pada seluruh line staging.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND LTRIM(RTRIM(cust_num)) <> @CustNum
        )
            THROW 50007, N'Satu Cust PO hanya boleh memiliki satu customer.', 1;

        IF @OrderDate IS NULL
            THROW 50008, N'order_date wajib diisi.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND (order_date IS NULL OR order_date <> @OrderDate)
        )
            THROW 50009, N'Satu Cust PO hanya boleh memiliki satu order_date.', 1;

        IF NULLIF(@Whse, N'') IS NULL
            THROW 50010, N'whse wajib diisi.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND
              (
                  NULLIF(LTRIM(RTRIM(whse)), N'') IS NULL
                  OR LTRIM(RTRIM(whse)) <> @Whse
              )
        )
            THROW 50011, N'Satu Cust PO hanya boleh memiliki satu warehouse.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND NULLIF(LTRIM(RTRIM(item)), N'') IS NULL
        )
            THROW 50012, N'item wajib diisi pada seluruh line staging.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND ISNULL(qty_ordered, 0) <= 0
        )
            THROW 50013, N'qty_ordered harus lebih besar dari nol.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND ISNULL(unit_price, 0) < 0
        )
            THROW 50014, N'unit_price tidak boleh negatif.', 1;

        IF @StageTermsCode IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM dbo.ue_SMK069_temp_sales_mst
               WHERE SiteRef = @SiteRef
                 AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
                 AND NULLIF(LTRIM(RTRIM(terms_code)), N'') IS NOT NULL
                 AND LTRIM(RTRIM(terms_code)) <> @StageTermsCode
           )
            THROW 50015, N'Satu Cust PO hanya boleh memiliki satu terms_code.', 1;

        IF @StageTaxCode IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM dbo.ue_SMK069_temp_sales_mst
               WHERE SiteRef = @SiteRef
                 AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
                 AND NULLIF(LTRIM(RTRIM(tax_code1)), N'') IS NOT NULL
                 AND LTRIM(RTRIM(tax_code1)) <> @StageTaxCode
           )
            THROW 50016, N'Satu Cust PO hanya boleh memiliki satu tax_code1.', 1;

        /* =============================================================
           2. Validate master data
           ============================================================= */
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.customer_mst
            WHERE site_ref = @SiteRef
              AND LTRIM(RTRIM(cust_num)) = @CustNum
              AND cust_seq = @CustSeq
        )
            THROW 50017, N'Customer/customer sequence tidak ditemukan pada site tersebut.', 1;

        SELECT
            @Contact           = contact##1,
            @Phone             = phone##1,
            @TermsCode         = terms_code,
            @TaxCode           = tax_code1,
            @EndUserType       = end_user_type,
            @IncludeTaxInPrice = include_tax_in_price
        FROM dbo.customer_mst
        WHERE site_ref = @SiteRef
          AND LTRIM(RTRIM(cust_num)) = @CustNum
          AND cust_seq = @CustSeq;

        SET @TermsCode = COALESCE(@StageTermsCode, @TermsCode);
        SET @TaxCode = COALESCE(@StageTaxCode, @TaxCode);

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.whse_mst
            WHERE site_ref = @SiteRef
              AND LTRIM(RTRIM(whse)) = @Whse
        )
            THROW 50018, N'Warehouse tidak ditemukan pada site tersebut.', 1;

        SELECT TOP (1)
            @CurrCode = curr_code
        FROM dbo.customer_currency_mst
        WHERE LTRIM(RTRIM(cust_num)) = @CustNum
          AND is_default = 1
        ORDER BY curr_code;

        IF NULLIF(LTRIM(RTRIM(@CurrCode)), N'') IS NULL
            THROW 50019, N'Default customer currency tidak ditemukan.', 1;

        SELECT TOP (1)
            @BadItem = s.item
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        LEFT JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo
          AND i.item IS NULL;

        IF @BadItem IS NOT NULL
        BEGIN
            SET @ThrowMessage = N'Item tidak ditemukan pada item_mst: '
                              + LTRIM(RTRIM(@BadItem));
            THROW 50020, @ThrowMessage, 1;
        END;

        SELECT TOP (1)
            @BadItem = s.item
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo
          AND NULLIF(LTRIM(RTRIM(COALESCE(s.u_m, i.u_m))), N'') IS NULL;

        IF @BadItem IS NOT NULL
        BEGIN
            SET @ThrowMessage = N'U/M kosong pada staging dan item master untuk item: '
                              + LTRIM(RTRIM(@BadItem));
            THROW 50021, @ThrowMessage, 1;
        END;

        /* =============================================================
           3. Idempotency: customer + business Cust PO
           ============================================================= */
        SELECT TOP (1)
            @ExistingCoNum = co_num
        FROM dbo.co_mst WITH (UPDLOCK, HOLDLOCK)
        WHERE site_ref = @SiteRef
          AND LTRIM(RTRIM(cust_num)) = @CustNum
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
        ORDER BY RecordDate DESC;

        IF @ExistingCoNum IS NOT NULL
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.co_mst
                WHERE site_ref = @SiteRef
                  AND co_num = @ExistingCoNum
                  AND ISNULL([type], N'') <> N'B'
            )
                THROW 50031, N'Cust PO sudah memiliki Customer Order tetapi bukan Blanket type B.', 1;

            SELECT @ExistingLineCount = COUNT(*)
            FROM dbo.coitem_mst
            WHERE site_ref = @SiteRef
              AND co_num = @ExistingCoNum;

            IF ISNULL(@ExistingLineCount, 0) <> @LineCount
            BEGIN
                SET @ThrowMessage = N'Cust PO sudah memiliki Customer Order '
                                  + LTRIM(RTRIM(@ExistingCoNum))
                                  + N', tetapi jumlah line tidak sama dengan staging.';
                THROW 50022, @ThrowMessage, 1;
            END;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_temp_sales_mst AS s
                LEFT JOIN dbo.coitem_mst AS ci
                  ON ci.site_ref = @SiteRef
                 AND ci.co_num = @ExistingCoNum
                 AND ci.co_line = s.co_line
                WHERE s.SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo
                  AND
                  (
                      ci.co_line IS NULL
                      OR LTRIM(RTRIM(ci.item)) <> LTRIM(RTRIM(s.item))
                      OR ABS(ISNULL(ci.qty_ordered, 0) - ISNULL(s.qty_ordered, 0)) > 0.00000001
                  )
            )
            BEGIN
                SET @ThrowMessage = N'Cust PO sudah memiliki Customer Order '
                                  + LTRIM(RTRIM(@ExistingCoNum))
                                  + N', tetapi detail line berbeda dengan staging.';
                THROW 50023, @ThrowMessage, 1;
            END;

            /* Repair/validate completely missing Blanket lines. */
            SELECT @ExistingBlanketLineCount = COUNT(*)
            FROM dbo.co_bln_mst
            WHERE site_ref = @SiteRef
              AND co_num = @ExistingCoNum;

            IF ISNULL(@ExistingBlanketLineCount, 0) = 0
            BEGIN
                INSERT INTO dbo.co_bln_mst
                (
                    site_ref,
                    co_num,
                    co_line,
                    item,
                    blanket_qty,
                    cont_price,
                    stat,
                    u_m,
                    blanket_qty_conv,
                    cont_price_conv,
                    ship_site,
                    description,
                    cost_conv,
                    allow_on_pick_list,
                    whse
                )
                SELECT
                    @SiteRef,
                    @ExistingCoNum,
                    s.co_line,
                    LTRIM(RTRIM(s.item)),
                    s.qty_ordered,
                    s.unit_price,
                    N'O',
                    COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''), i.u_m),
                    s.qty_ordered,
                    s.unit_price,
                    @SiteRef,
                    i.description,
                    ISNULL(i.unit_cost, 0),
                    0,
                    @Whse
                FROM dbo.ue_SMK069_temp_sales_mst AS s
                INNER JOIN dbo.item_mst AS i
                  ON i.site_ref = s.SiteRef
                 AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
                WHERE s.SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo;

                IF @@ROWCOUNT <> @LineCount
                    THROW 50032, N'Jumlah Blanket Order line hasil repair tidak sama dengan staging.', 1;
            END
            ELSE IF @ExistingBlanketLineCount <> @LineCount
                THROW 50033, N'Existing Blanket Order memiliki jumlah blanket line berbeda dengan staging.', 1;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_temp_sales_mst AS s
                LEFT JOIN dbo.co_bln_mst AS b
                  ON b.site_ref = @SiteRef
                 AND b.co_num = @ExistingCoNum
                 AND b.co_line = s.co_line
                WHERE s.SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo
                  AND
                  (
                      b.co_line IS NULL
                      OR LTRIM(RTRIM(b.item)) <> LTRIM(RTRIM(s.item))
                      OR ABS(ISNULL(b.blanket_qty, 0) - ISNULL(s.qty_ordered, 0)) > 0.00000001
                      OR ABS(ISNULL(b.cont_price, 0) - ISNULL(s.unit_price, 0)) > 0.00000001
                      OR ISNULL(b.stat, N'') <> N'O'
                      OR ISNULL(b.allow_on_pick_list, 1) <> 0
                  )
            )
                THROW 50034, N'Existing Blanket Order detail berbeda dengan staging/target Auto CO.', 1;

            /* Released Date must equal actual CO header Order Date. */
            UPDATE ci
            SET ci.release_date = c.order_date
            FROM dbo.coitem_mst AS ci
            INNER JOIN dbo.co_mst AS c
                ON c.site_ref = ci.site_ref
               AND c.co_num = ci.co_num
            WHERE ci.site_ref = @SiteRef
              AND ci.co_num = @ExistingCoNum
              AND (ci.release_date IS NULL OR ci.release_date <> c.order_date);

            IF EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_temp_sales_mst AS x
                WHERE x.SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), x.co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(100), @ExistingCoNum)))
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), x.cust_po))) <> @CustPo
            )
                THROW 50036, N'Target SyteLine CO number sudah dipakai row staging lain.', 1;

            UPDATE dbo.ue_SMK069_temp_sales_mst
            SET
                co_num = @ExistingCoNum,
                process_status = N'P',
                validation_msg = NULL,
                error_msg = NULL,
                processed_date = GETDATE(),
                processed_by = @ProcessedBy,
                RecordDate = GETDATE(),
                UpdatedBy = @ProcessedBy
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo;

            SET @CreatedCoNum = @ExistingCoNum;
            SET @Success = 1;
            SET @Infobar = N'Customer Order '
                         + LTRIM(RTRIM(@CreatedCoNum))
                         + N' sudah pernah dibuat untuk Cust PO '
                         + @CustPo
                         + N'; staging disinkronkan menjadi Processed.';

            COMMIT TRANSACTION;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND process_status = N'P'
        )
            THROW 50024, N'Staging berstatus Processed tetapi Customer Order terkait tidak ditemukan.', 1;

        /* =============================================================
           4. Calculate totals
           ============================================================= */
        SELECT
            @HeaderMatlCost = SUM(ISNULL(i.matl_cost, 0) * s.qty_ordered),
            @HeaderCost     = SUM(ISNULL(i.unit_cost, 0) * s.qty_ordered),
            @HeaderPrice    = SUM(ISNULL(s.unit_price, 0) * s.qty_ordered)
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo;

        SET @HeaderMatlCost = ISNULL(@HeaderMatlCost, 0);
        SET @HeaderCost = ISNULL(@HeaderCost, 0);
        SET @HeaderPrice = ISNULL(@HeaderPrice, 0);

        /* =============================================================
           5. Generate P + YYMMDD + 3-digit daily running
           ============================================================= */
        SET @KeyPrefix = N'P' + CONVERT(CHAR(6), @OrderDate, 12);
        SET @NumberLength = 3;

        SET @LockResource = N'SMK069_CO_NUM|'
                          + LTRIM(RTRIM(@SiteRef))
                          + N'|'
                          + LTRIM(RTRIM(@KeyPrefix));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = N'Exclusive',
            @LockOwner = N'Transaction',
            @LockTimeout = 15000;

        IF @LockResult < 0
            THROW 50025, N'Gagal memperoleh lock untuk pembuatan nomor Customer Order.', 1;

        SELECT
            @KeyID = ISNULL
            (
                MAX
                (
                    TRY_CONVERT
                    (
                        BIGINT,
                        SUBSTRING
                        (
                            LTRIM(RTRIM(co_num)),
                            LEN(@KeyPrefix) + 1,
                            @NumberLength
                        )
                    )
                ),
                0
            ) + 1
        FROM dbo.co_mst WITH (UPDLOCK, HOLDLOCK)
        WHERE site_ref = @SiteRef
          AND LTRIM(RTRIM(co_num)) LIKE @KeyPrefix + N'%'
          AND LEN(LTRIM(RTRIM(co_num))) = LEN(@KeyPrefix) + @NumberLength;

        SET @MaxKeyID = CONVERT(BIGINT, POWER(CONVERT(FLOAT, 10), @NumberLength)) - 1;

        IF @KeyID > @MaxKeyID
            THROW 50026, N'Nomor Customer Order untuk tanggal tersebut sudah penuh.', 1;

        SET @CreatedCoNum = CONVERT
        (
            NVARCHAR(10),
            @KeyPrefix
            + RIGHT
              (
                  REPLICATE(N'0', @NumberLength)
                  + CONVERT(NVARCHAR(20), @KeyID),
                  @NumberLength
              )
        );

        IF EXISTS
        (
            SELECT 1
            FROM dbo.co_mst
            WHERE site_ref = @SiteRef
              AND co_num = @CreatedCoNum
        )
            THROW 50027, N'Nomor Customer Order yang dihasilkan sudah digunakan.', 1;

        /* =============================================================
           6. Insert Blanket Customer Order header
           ============================================================= */
        INSERT INTO dbo.co_mst
        (
            co_num,
            cust_num,
            cust_po,
            [type],
            cust_seq,
            whse,
            order_date,
            curr_code,
            site_ref,
            contact,
            phone,
            terms_code,
            tax_code1,
            end_user_type,
            orig_site,
            include_tax_in_price,
            consolidate,
            [cost],
            matl_cost_t,
            price
        )
        VALUES
        (
            @CreatedCoNum,
            @CustNum,
            @CustPo,
            N'B',
            @CustSeq,
            @Whse,
            @OrderDate,
            @CurrCode,
            @SiteRef,
            @Contact,
            @Phone,
            @TermsCode,
            @TaxCode,
            @EndUserType,
            @SiteRef,
            @IncludeTaxInPrice,
            1,
            @HeaderCost,
            @HeaderMatlCost,
            @HeaderPrice
        );

        /* =============================================================
           7. Insert CO lines
           ============================================================= */
        INSERT INTO dbo.coitem_mst
        (
            co_num,
            co_line,
            item,
            qty_ordered,
            u_m,
            due_date,
            release_date,
            price,
            site_ref,
            whse,
            qty_ordered_conv,
            cust_seq,
            co_cust_num,
            ship_site,
            co_orig_site,
            description,
            [cost],
            cgs_total,
            price_conv,
            matl_cost,
            cost_conv,
            matl_cost_conv,
            stat,
            consolidate
        )
        SELECT
            @CreatedCoNum,
            s.co_line,
            LTRIM(RTRIM(s.item)),
            s.qty_ordered,
            COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''), i.u_m),
            COALESCE(s.due_date, @OrderDate),
            @OrderDate,
            s.unit_price,
            @SiteRef,
            @Whse,
            s.qty_ordered,
            @CustSeq,
            @CustNum,
            @SiteRef,
            @SiteRef,
            i.description,
            ISNULL(i.unit_cost, 0),
            ISNULL(i.unit_cost, 0),
            s.unit_price,
            ISNULL(i.matl_cost, 0),
            ISNULL(i.unit_cost, 0),
            ISNULL(i.matl_cost, 0),
            N'O',
            1
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo;

        IF @@ROWCOUNT <> @LineCount
            THROW 50028, N'Jumlah Customer Order line yang dibuat tidak sama dengan staging.', 1;

        /* =============================================================
           8. Insert Blanket lines
           ============================================================= */
        INSERT INTO dbo.co_bln_mst
        (
            site_ref,
            co_num,
            co_line,
            item,
            blanket_qty,
            cont_price,
            stat,
            u_m,
            blanket_qty_conv,
            cont_price_conv,
            ship_site,
            description,
            cost_conv,
            allow_on_pick_list,
            whse
        )
        SELECT
            @SiteRef,
            @CreatedCoNum,
            s.co_line,
            LTRIM(RTRIM(s.item)),
            s.qty_ordered,
            s.unit_price,
            N'O',
            COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''), i.u_m),
            s.qty_ordered,
            s.unit_price,
            @SiteRef,
            i.description,
            ISNULL(i.unit_cost, 0),
            0,
            @Whse
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo;

        IF @@ROWCOUNT <> @LineCount
            THROW 50035, N'Jumlah Blanket Order line yang dibuat tidak sama dengan staging.', 1;

        /* =============================================================
           9. Persist actual SyteLine CO into temp and mark Processed
           ============================================================= */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst AS x
            WHERE x.SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), x.co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(100), @CreatedCoNum)))
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), x.cust_po))) <> @CustPo
        )
            THROW 50037, N'Generated SyteLine CO number sudah dipakai row staging lain.', 1;

        UPDATE dbo.ue_SMK069_temp_sales_mst
        SET
            co_num = @CreatedCoNum,
            process_status = N'P',
            validation_msg = NULL,
            error_msg = NULL,
            processed_date = GETDATE(),
            processed_by = @ProcessedBy,
            RecordDate = GETDATE(),
            UpdatedBy = @ProcessedBy
        WHERE SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo;

        COMMIT TRANSACTION;

        SET @Success = 1;
        SET @Infobar = N'Customer Order '
                     + LTRIM(RTRIM(@CreatedCoNum))
                     + N' berhasil dibuat untuk Cust PO '
                     + @CustPo
                     + N'.';
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = LEFT
        (
            N'Error '
            + CONVERT(NVARCHAR(20), ERROR_NUMBER())
            + N' pada line '
            + CONVERT(NVARCHAR(20), ERROR_LINE())
            + N': '
            + ERROR_MESSAGE(),
            4000
        );

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @CreatedCoNum = NULL;
        SET @Success = 0;
        SET @Infobar = CONVERT(NVARCHAR(2800), @ErrorMessage);

        BEGIN TRY
            IF NULLIF(@CustPo, N'') IS NOT NULL
            BEGIN
                UPDATE dbo.ue_SMK069_temp_sales_mst
                SET
                    process_status = N'E',
                    error_msg = @ErrorMessage,
                    retry_count = ISNULL(retry_count, 0) + 1,
                    processed_date = NULL,
                    processed_by = @ProcessedBy,
                    RecordDate = GETDATE(),
                    UpdatedBy = @ProcessedBy
                WHERE SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo;
            END;
        END TRY
        BEGIN CATCH
            SET @Infobar = CONVERT
            (
                NVARCHAR(2800),
                LEFT
                (
                    @ErrorMessage
                    + N' | Gagal memperbarui status staging: '
                    + ERROR_MESSAGE(),
                    4000
                )
            );
        END CATCH;
    END CATCH;
END;
GO