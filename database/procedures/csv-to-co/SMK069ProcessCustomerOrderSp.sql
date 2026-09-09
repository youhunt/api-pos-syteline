/*
    Procedure : dbo.SMK069ProcessCustomerOrderSp
    Tenant    : LENSA_SL_CSI_BAK / DEV

    Tenant-confirmed simplifications:
    - no @Sparepart parameter
    - no pickup/start/end-time parameters
    - no unavailable portal Uf_* columns
    - generated Customer Order pattern = COYYMM####
    - source/POS co_num remains in staging and is stored in co_mst.cust_po
*/

CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp
    @SiteRef       SiteType,
    @SourceCoNum   CoNumType,
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
        @CustNum                 CustNumType,
        @OrderDate               DateType,
        @Whse                    WhseType,
        @StageTermsCode          TermsCodeType,
        @StageTaxCode            TaxCodeType,
        @TermsCode               TermsCodeType,
        @TaxCode                 TaxCodeType,
        @CurrCode                CurrCodeType,
        @Contact                 ContactType,
        @Phone                   PhoneType,
        @EndUserType             EndUserTypeType,
        @IncludeTaxInPrice       ListYesNoType,
        @HeaderCost              AmountType,
        @HeaderMatlCost          AmountType,
        @HeaderPrice             AmountType,
        @KeyPrefix               GenericKeyType,
        @KeyID                   BIGINT,
        @NumberLength            INT,
        @MaxKeyID                BIGINT,
        @LineCount               INT,
        @ExistingLineCount       INT,
        @ExistingCoNum           CoNumType,
        @BadItem                 ItemType,
        @LockResult              INT,
        @LockResource            NVARCHAR(255),
        @ErrorMessage            NVARCHAR(4000),
        @ThrowMessage            NVARCHAR(2048);

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
           1. Validate request and lock selected staging order
           ============================================================= */
        IF NULLIF(@SiteRef, N'') IS NULL
            THROW 50001, N'SiteRef wajib diisi.', 1;

        IF NULLIF(@SourceCoNum, N'') IS NULL
            THROW 50002, N'Source/POS co_num wajib diisi.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst WITH (UPDLOCK, HOLDLOCK)
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
        )
            THROW 50003, N'Data staging untuk SiteRef dan source co_num tersebut tidak ditemukan.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst WITH (UPDLOCK, HOLDLOCK)
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
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
          AND LTRIM(RTRIM(co_num)) = @SourceCoNum;

        IF ISNULL(@LineCount, 0) = 0
            THROW 50005, N'Order staging tidak memiliki line.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
              AND NULLIF(LTRIM(RTRIM(cust_num)), N'') IS NULL
        )
            THROW 50006, N'cust_num wajib diisi pada seluruh line staging.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
              AND LTRIM(RTRIM(cust_num)) <> @CustNum
        )
            THROW 50007, N'Satu source co_num hanya boleh memiliki satu customer.', 1;

        IF @OrderDate IS NULL
            THROW 50008, N'order_date wajib diisi.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
              AND (order_date IS NULL OR order_date <> @OrderDate)
        )
            THROW 50009, N'Satu source co_num hanya boleh memiliki satu order_date.', 1;

        IF NULLIF(@Whse, N'') IS NULL
            THROW 50010, N'whse wajib diisi.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
              AND
              (
                  NULLIF(LTRIM(RTRIM(whse)), N'') IS NULL
                  OR LTRIM(RTRIM(whse)) <> @Whse
              )
        )
            THROW 50011, N'Satu source co_num hanya boleh memiliki satu warehouse.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
              AND NULLIF(LTRIM(RTRIM(item)), N'') IS NULL
        )
            THROW 50012, N'item wajib diisi pada seluruh line staging.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
              AND ISNULL(qty_ordered, 0) <= 0
        )
            THROW 50013, N'qty_ordered harus lebih besar dari nol.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
              AND ISNULL(unit_price, 0) < 0
        )
            THROW 50014, N'unit_price tidak boleh negatif.', 1;

        IF @StageTermsCode IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM dbo.ue_SMK069_temp_sales_mst
               WHERE SiteRef = @SiteRef
                 AND LTRIM(RTRIM(co_num)) = @SourceCoNum
                 AND NULLIF(LTRIM(RTRIM(terms_code)), N'') IS NOT NULL
                 AND LTRIM(RTRIM(terms_code)) <> @StageTermsCode
           )
            THROW 50015, N'Satu source co_num hanya boleh memiliki satu terms_code.', 1;

        IF @StageTaxCode IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM dbo.ue_SMK069_temp_sales_mst
               WHERE SiteRef = @SiteRef
                 AND LTRIM(RTRIM(co_num)) = @SourceCoNum
                 AND NULLIF(LTRIM(RTRIM(tax_code1)), N'') IS NOT NULL
                 AND LTRIM(RTRIM(tax_code1)) <> @StageTaxCode
           )
            THROW 50016, N'Satu source co_num hanya boleh memiliki satu tax_code1.', 1;

        /* =============================================================
           2. Validate customer, warehouse, currency, and item master data
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
          AND LTRIM(RTRIM(s.co_num)) = @SourceCoNum
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
          AND LTRIM(RTRIM(s.co_num)) = @SourceCoNum
          AND NULLIF(LTRIM(RTRIM(COALESCE(s.u_m, i.u_m))), N'') IS NULL;

        IF @BadItem IS NOT NULL
        BEGIN
            SET @ThrowMessage = N'U/M kosong pada staging dan item master untuk item: '
                              + LTRIM(RTRIM(@BadItem));
            THROW 50021, @ThrowMessage, 1;
        END;

        /* =============================================================
           3. Idempotency through co_mst.cust_po
           ============================================================= */
        SELECT TOP (1)
            @ExistingCoNum = co_num
        FROM dbo.co_mst WITH (UPDLOCK, HOLDLOCK)
        WHERE site_ref = @SiteRef
          AND LTRIM(RTRIM(cust_num)) = @CustNum
          AND LTRIM(RTRIM(cust_po)) = @SourceCoNum
        ORDER BY RecordDate DESC;

        IF @ExistingCoNum IS NOT NULL
        BEGIN
            SELECT
                @ExistingLineCount = COUNT(*)
            FROM dbo.coitem_mst
            WHERE site_ref = @SiteRef
              AND co_num = @ExistingCoNum;

            IF ISNULL(@ExistingLineCount, 0) <> @LineCount
            BEGIN
                SET @ThrowMessage = N'Source order sudah memiliki Customer Order '
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
                  AND LTRIM(RTRIM(s.co_num)) = @SourceCoNum
                  AND
                  (
                      ci.co_line IS NULL
                      OR LTRIM(RTRIM(ci.item)) <> LTRIM(RTRIM(s.item))
                      OR ABS(ISNULL(ci.qty_ordered, 0) - ISNULL(s.qty_ordered, 0)) > 0.00000001
                  )
            )
            BEGIN
                SET @ThrowMessage = N'Source order sudah memiliki Customer Order '
                                  + LTRIM(RTRIM(@ExistingCoNum))
                                  + N', tetapi detail line berbeda dengan staging.';
                THROW 50023, @ThrowMessage, 1;
            END;

            UPDATE dbo.ue_SMK069_temp_sales_mst
            SET
                process_status = N'P',
                validation_msg = NULL,
                error_msg = NULL,
                processed_date = GETDATE(),
                processed_by = @ProcessedBy,
                RecordDate = GETDATE(),
                UpdatedBy = @ProcessedBy
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum;

            SET @CreatedCoNum = @ExistingCoNum;
            SET @Success = 1;
            SET @Infobar = N'Customer Order '
                         + LTRIM(RTRIM(@CreatedCoNum))
                         + N' sudah pernah dibuat; staging disinkronkan menjadi Processed.';

            COMMIT TRANSACTION;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum
              AND process_status = N'P'
        )
            THROW 50024, N'Staging berstatus Processed tetapi Customer Order terkait tidak ditemukan.', 1;

        /* =============================================================
           4. Calculate header totals from staging and item master
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
          AND LTRIM(RTRIM(s.co_num)) = @SourceCoNum;

        SET @HeaderMatlCost = ISNULL(@HeaderMatlCost, 0);
        SET @HeaderCost = ISNULL(@HeaderCost, 0);
        SET @HeaderPrice = ISNULL(@HeaderPrice, 0);

        /* =============================================================
           5. Generate one concurrency-safe Customer Order number
              Current tenant pattern: COYYMM####
           ============================================================= */
        SET @KeyPrefix = N'CO' + CONVERT(CHAR(4), @OrderDate, 12);
        SET @NumberLength = 4;

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
            THROW 50026, N'Nomor Customer Order untuk prefix tersebut sudah penuh.', 1;

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
           6. Insert Customer Order header
           ============================================================= */
        INSERT INTO dbo.co_mst
        (
            co_num,
            cust_num,
            cust_po,
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
            [cost],
            matl_cost_t,
            price
        )
        VALUES
        (
            @CreatedCoNum,
            @CustNum,
            @SourceCoNum,
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
            @HeaderCost,
            @HeaderMatlCost,
            @HeaderPrice
        );

        /* =============================================================
           7. Insert all Customer Order lines with same @CreatedCoNum
           ============================================================= */
        INSERT INTO dbo.coitem_mst
        (
            co_num,
            co_line,
            item,
            qty_ordered,
            u_m,
            due_date,
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
            matl_cost_conv
        )
        SELECT
            @CreatedCoNum,
            s.co_line,
            LTRIM(RTRIM(s.item)),
            s.qty_ordered,
            COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''), i.u_m),
            COALESCE(s.due_date, @OrderDate),
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
            ISNULL(i.matl_cost, 0)
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(s.co_num)) = @SourceCoNum;

        IF @@ROWCOUNT <> @LineCount
            THROW 50028, N'Jumlah Customer Order line yang dibuat tidak sama dengan staging.', 1;

        /* =============================================================
           8. Mark staging Processed and commit
           ============================================================= */
        UPDATE dbo.ue_SMK069_temp_sales_mst
        SET
            process_status = N'P',
            validation_msg = NULL,
            error_msg = NULL,
            processed_date = GETDATE(),
            processed_by = @ProcessedBy,
            RecordDate = GETDATE(),
            UpdatedBy = @ProcessedBy
        WHERE SiteRef = @SiteRef
          AND LTRIM(RTRIM(co_num)) = @SourceCoNum;

        COMMIT TRANSACTION;

        SET @Success = 1;
        SET @Infobar = N'Customer Order '
                     + LTRIM(RTRIM(@CreatedCoNum))
                     + N' berhasil dibuat dari source order '
                     + @SourceCoNum
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
              AND LTRIM(RTRIM(co_num)) = @SourceCoNum;
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
