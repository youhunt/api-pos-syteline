/* =============================================================================
   SMK069 - Partial Success Enablement, Patch 03 of 03
   -----------------------------------------------------------------------------
   Object   : dbo.SMK069RunCsvTestBatchSp                    (PATCHED)
   Date     : 2026-09-04
   Depends  : Patch 01 (dbo.SMK069ProcessBatchCustomerOrdersSp)
              dbo.SMK069ReceivePosSalesJsonCoreSp            (UNCHANGED)
              dbo.SMK069ImportCsvFileSp                      (UNCHANGED)

   >>> BEFORE APPLY DATABASE <<<
   Diff the parameter block against the tenant. Positions 1-10 MUST stay exactly
   as they are today. @CreatedCoNums is appended as position 11 WITH A DEFAULT,
   so any existing IDO method or form script that passes 10 parameters keeps
   working unchanged.

   THIS IS THE CSV -> CUSTOMER ORDER ONE-HIT CHANGE
   ------------------------------------------------
   The procedure previously stopped at Receive. Its own Infobar said so:
   "Customer Order belum dibuat; lanjutkan Process/Reprocess." The outputs
   @ProcessedOrders and @ProcessErrorOrders already existed but were never
   filled, and processed_orders / process_error_orders were written to
   ue_SMK069_pos_csv_batch_mst as the literals 0, 0.

   WHAT CHANGED AND WHY
   --------------------
   1. THE VALIDATION GATE.

      was:  @ReturnCode <> 0 OR @ReceivedRows = 0 OR @TotalOrders = 0
            OR @ValidationValidOrders = 0 OR @ValidationErrorOrders > 0
            OR @TransferredRows = 0
      now:  @TransferredRows = 0

      Same reasoning as patch 02. Core validates per atomic order and COMMITS
      the valid ones before returning 16, so rejecting the whole batch on
      @ValidationErrorOrders > 0 stranded already-persisted orders in
      ue_SMK069_temp_sales_mst at process_status = 'V' with no way back except
      a manual per-order Process call.

   2. PROCESS IS NOW CALLED.
      Via dbo.SMK069ProcessBatchCustomerOrdersSp, the same loop the JSON path
      uses. One transaction per order; a bad coline fails only its own CO.

   3. REAL COUNTS ARE PERSISTED.
      processed_orders and process_error_orders now carry the actual numbers.

   4. batch_status GAINS 'P'.
      C = every order became a Customer Order
      P = partial; some orders failed validation or Process, the rest are done
      E = nothing landed
      R = running

   5. upload_status IS NOW PER ROW.
      It used to be one value stamped across the whole batch. A row is 'S' when
      its cust_po reached inbound_status = 'T', otherwise 'E'.

   RETRY
   -----
   Run this procedure again with the SAME batch_id. Core takes its idempotent
   replay branch and writes nothing; the Process loop then picks up only the
   orders still at 'V' or 'E'. Orders already at 'P' are skipped and reported
   separately, so the counts stay honest. There is no need to cut the CSV file
   down to the failed rows.

   TRANSACTION REQUIREMENT
   -----------------------
   Any IDO method or form script calling this MUST NOT be Transactional.
   See patch 01 for the reason.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069RunCsvTestBatchSp
    -- ----- positions 1-10: UNCHANGED, do not reorder -------------------------
    @BatchId               NVARCHAR(100),
    @RequestedBy           NVARCHAR(128) = NULL,
    @ReceivedRows          INT OUTPUT,
    @TotalOrders           INT OUTPUT,
    @ValidationValidOrders INT OUTPUT,
    @ValidationErrorOrders INT OUTPUT,
    @TransferredRows       INT OUTPUT,
    @ProcessedOrders       INT OUTPUT,
    @ProcessErrorOrders    INT OUTPUT,
    @Infobar               NVARCHAR(4000) OUTPUT,
    -- ----- position 11: NEW, defaulted so old metadata still binds -----------
    @CreatedCoNums         NVARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    -- ACTIVE SITE CONTEXT (SMK069 Site-Aware Hardening 2026-09-03)
    ----------------------------------------------------------------
    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'');
    SET @RequestedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@RequestedBy)), N''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ReceivedRows          = 0;
    SET @TotalOrders           = 0;
    SET @ValidationValidOrders = 0;
    SET @ValidationErrorOrders = 0;
    SET @TransferredRows       = 0;
    SET @ProcessedOrders       = 0;
    SET @ProcessErrorOrders    = 0;
    SET @CreatedCoNums         = NULL;
    SET @Infobar               = NULL;

    /* =========================================================================
       0. Pre-flight. UNCHANGED from the previous revision.
       ========================================================================= */
    IF @BatchId IS NULL
    BEGIN
        SET @Infobar = N'[POS-012] batch_id wajib diisi.';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_batch_mst
        WHERE SiteRef = @Site
          AND batch_id = @BatchId
    )
    BEGIN
        SET @Infobar = N'[POS-401] Batch CSV tidak ditemukan.';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE SiteRef = @Site
          AND batch_id = @BatchId
    )
    BEGIN
        SET @Infobar = N'[POS-402] Batch CSV belum memiliki detail transaksi.';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE SiteRef = @Site
          AND batch_id = @BatchId
          AND upload_status = N'E'
          AND NULLIF(LTRIM(RTRIM(result_message)), N'') IS NULL
    )
    BEGIN
        SET @Infobar =
            N'[POS-404] Batch memiliki detail parsing berstatus Error. '
            + N'Perbaiki CSV lalu Re-Parse sebelum Import & Validate.';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE SiteRef = @Site
          AND batch_id = @BatchId
          AND
          (
              NULLIF(LTRIM(RTRIM(custnum)), N'') IS NULL
              OR order_date IS NULL
              OR NULLIF(LTRIM(RTRIM(cust_po)), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(whse)), N'') IS NULL
              OR ISNULL(coline, 0) <= 0
              OR NULLIF(LTRIM(RTRIM(item)), N'') IS NULL
              OR ISNULL(qty_ordered, 0) <= 0
              OR NULLIF(LTRIM(RTRIM(u_m)), N'') IS NULL
          )
    )
    BEGIN
        SET @Infobar =
            N'[POS-404] CSV Contract V2 belum lengkap. Wajib: '
            + N'custnum, order_date, cust_po, whse, coline, item, qty_ordered, u_m.';
        RETURN 16;
    END;

    DECLARE
        @ConfiguredSourceSystem NVARCHAR(50),
        @SourceSystem           NVARCHAR(50),
        @PayloadJson            NVARCHAR(MAX),
        @ReceiverInfo           NVARCHAR(4000),
        @ReturnCode             INT            = 0,
        @HardFailed             BIT            = 0,
        @Partial                BIT            = 0,
        @ResultCode             NVARCHAR(20)   = NULL,
        @ProcessErrorCode       NVARCHAR(20)   = NULL,
        @ProcessDetail          NVARCHAR(2800) = NULL,
        @SkippedOrders          INT            = 0,
        @CodePos                INT            = 0;

    SELECT
        @ConfiguredSourceSystem = UPPER
        (
            COALESCE(NULLIF(LTRIM(RTRIM(source_system)), N''), N'POS')
        )
    FROM dbo.ue_SMK069_pos_csv_batch_mst
    WHERE SiteRef = @Site
      AND batch_id = @BatchId;

    SET @SourceSystem =
        CASE
            WHEN @ConfiguredSourceSystem IN
                 (N'POS-CSV-TEST', N'POS_CSV_TEST', N'CSV-TEST', N'CSV_TEST')
            THEN N'POS'
            ELSE @ConfiguredSourceSystem
        END;

    UPDATE dbo.ue_SMK069_pos_csv_batch_mst
    SET
        batch_status   = N'R',
        started_date   = GETDATE(),
        completed_date = NULL,
        result_message =
            N'Import, Validate & Process menggunakan '
            + N'ue_SMK069_pos_sales_inbound_mapping_view.',
        UpdatedBy      = @RequestedBy,
        RecordDate     = GETDATE()
    WHERE SiteRef = @Site
      AND batch_id = @BatchId;

    /* =========================================================================
       1. Build RAW POS JSON only. No business mapping in the CSV wrapper.
          UNCHANGED.
       ========================================================================= */
    SELECT
        @PayloadJson =
        (
            SELECT
                LTRIM(RTRIM(d.custnum))                    AS custnum,
                CONVERT(NVARCHAR(10), d.order_date, 23)    AS order_date,
                LTRIM(RTRIM(d.cust_po))                    AS cust_po,
                LTRIM(RTRIM(d.whse))                       AS whse,
                d.coline                                   AS coline,
                LTRIM(RTRIM(d.item))                       AS item,
                d.qty_ordered                              AS qty_ordered,
                LTRIM(RTRIM(d.u_m))                        AS u_m,
                CONVERT(NVARCHAR(8), @Site)                AS siteref,
                CASE
                    WHEN d.due_date IS NULL THEN NULL
                    ELSE CONVERT(NVARCHAR(10), d.due_date, 23)
                END                                        AS due_date,
                NULLIF(LTRIM(RTRIM(d.terms_code)), N'')    AS terms_code,
                NULLIF(LTRIM(RTRIM(d.tax_code1)), N'')     AS tax_code1,
                d.exch_rate                                AS exch_rate
            FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
            WHERE d.SiteRef = @Site
              AND d.batch_id = @BatchId
            ORDER BY d.row_no
            FOR JSON PATH
        );

    IF ISJSON(@PayloadJson) <> 1 OR @PayloadJson = N'[]'
    BEGIN
        SET @Infobar = N'[POS-405] JSON transaksi dari CSV gagal dibentuk atau kosong.';

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET batch_status   = N'E',
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            UpdatedBy      = @RequestedBy,
            RecordDate     = GETDATE()
        WHERE SiteRef = @Site
          AND batch_id = @BatchId;

        RETURN 16;
    END;

    BEGIN TRY
        /* =====================================================================
           2. Receive. Per-order validation, commits what is valid.
           ===================================================================== */
        EXEC @ReturnCode = dbo.SMK069ReceivePosSalesJsonCoreSp
            @SourceSystem    = @SourceSystem,
            @BatchId         = @BatchId,
            @PayloadJson     = @PayloadJson,
            @ReceivedBy      = @RequestedBy,
            @ReceivedRows    = @ReceivedRows          OUTPUT,
            @TotalOrders     = @TotalOrders           OUTPUT,
            @ValidOrders     = @ValidationValidOrders OUTPUT,
            @ErrorOrders     = @ValidationErrorOrders OUTPUT,
            @TransferredRows = @TransferredRows       OUTPUT,
            @Infobar         = @ReceiverInfo          OUTPUT;

        /* Total failure only. @TransferredRows > 0 means something landed. */
        IF ISNULL(@TransferredRows, 0) = 0
            SET @HardFailed = 1;

        /* =====================================================================
           3. Process. Skipped entirely when nothing landed.
           ===================================================================== */
        IF @HardFailed = 0
        BEGIN
            EXEC dbo.SMK069ProcessBatchCustomerOrdersSp
                @SourceSystem    = @SourceSystem,
                @BatchId         = @BatchId,
                @ProcessedBy     = @RequestedBy,
                @ProcessedOrders = @ProcessedOrders    OUTPUT,
                @ProcessErrors   = @ProcessErrorOrders OUTPUT,
                @SkippedOrders   = @SkippedOrders      OUTPUT,
                @FirstErrorCode  = @ProcessErrorCode   OUTPUT,
                @ProcessDetail   = @ProcessDetail      OUTPUT,
                @CreatedCoNums   = @CreatedCoNums      OUTPUT;

            IF ISNULL(@ValidationErrorOrders, 0) > 0
               OR ISNULL(@ProcessErrorOrders, 0) > 0
                SET @Partial = 1;
        END;

        /* =====================================================================
           4. Result code and message.
           ===================================================================== */
        IF @HardFailed = 1
        BEGIN
            SELECT TOP (1)
                @ResultCode =
                    CASE
                        WHEN CHARINDEX(N'[POS-', COALESCE(e.validation_msg, N'')) > 0
                         AND SUBSTRING
                             (
                                 e.validation_msg,
                                 CHARINDEX(N'[POS-', e.validation_msg) + 8,
                                 1
                             ) = N']'
                        THEN SUBSTRING
                             (
                                 e.validation_msg,
                                 CHARINDEX(N'[POS-', e.validation_msg) + 1,
                                 7
                             )
                        ELSE NULL
                    END
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
            WHERE e.SiteRef        = @Site
              AND e.source_system  = @SourceSystem
              AND e.batch_id       = @BatchId
              AND e.inbound_status = N'E'
            ORDER BY
                CASE
                    WHEN e.validation_msg LIKE N'Order memiliki line lain%' THEN 1
                    ELSE 0
                END,
                e.row_no;

            IF NULLIF(@ResultCode, N'') IS NULL
            BEGIN
                SET @CodePos = CHARINDEX(N'[POS-', COALESCE(@ReceiverInfo, N''));
                IF @CodePos > 0
                   AND SUBSTRING(@ReceiverInfo, @CodePos + 1, 7) = N'POS-000'
                    SET @CodePos = CHARINDEX(N'[POS-', @ReceiverInfo, @CodePos + 5);
                IF @CodePos > 0
                   AND SUBSTRING(@ReceiverInfo, @CodePos + 8, 1) = N']'
                    SET @ResultCode = SUBSTRING(@ReceiverInfo, @CodePos + 1, 7);
            END;

            SET @ResultCode = COALESCE(NULLIF(@ResultCode, N''), N'POS-999');

            SET @Infobar = LEFT
            (
                N'[' + @ResultCode + N'] Import & Validate gagal. '
                + N'Tidak ada order yang masuk ke proses Customer Order. '
                + COALESCE(NULLIF(@ReceiverInfo, N''), N'Business validation gagal.'),
                4000
            );

            IF ISNULL(@ReturnCode, 0) = 0
                SET @ReturnCode = 16;
        END
        ELSE
        BEGIN
            SET @Infobar = LEFT
            (
                CASE
                    WHEN @Partial = 1
                    THEN N'[' + COALESCE(NULLIF(@ProcessErrorCode, N''), N'POS-000')
                         + N'] PARTIAL. '
                    ELSE N'[POS-000] '
                END
                + COALESCE(NULLIF(@ReceiverInfo, N''), N'Import & Validate selesai.')
                + N' ProcessedOrders=' + CONVERT(NVARCHAR(20), @ProcessedOrders)
                + N'; ProcessErrors='  + CONVERT(NVARCHAR(20), @ProcessErrorOrders)
                + N'; SkippedOrders='  + CONVERT(NVARCHAR(20), @SkippedOrders)
                + CASE
                      WHEN NULLIF(@CreatedCoNums, N'') IS NULL THEN N''
                      ELSE N'. CreatedCoNums: ' + @CreatedCoNums
                  END
                + CASE
                      WHEN NULLIF(@ProcessDetail, N'') IS NULL THEN N''
                      ELSE N'. ProcessDetail: ' + @ProcessDetail
                  END,
                4000
            );

            SET @ReturnCode = 0;
        END;

        /* =====================================================================
           5. Persist per-row and per-batch outcome.
           ===================================================================== */
        UPDATE d
        SET
            upload_status =
                CASE
                    WHEN EXISTS
                    (
                        SELECT 1
                        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                        WHERE i.SiteRef       = @Site
                          AND i.source_system = @SourceSystem
                          AND i.batch_id      = @BatchId
                          AND i.inbound_status = N'T'
                          AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po))))
                                  COLLATE DATABASE_DEFAULT
                              = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), d.cust_po))))
                                  COLLATE DATABASE_DEFAULT
                    )
                    THEN N'S'
                    ELSE N'E'
                END,
            result_message = LEFT(@Infobar, 1000),
            processed_date = GETDATE(),
            UpdatedBy      = @RequestedBy,
            RecordDate     = GETDATE()
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
        WHERE d.SiteRef = @Site
          AND d.batch_id = @BatchId;

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            batch_status =
                CASE
                    WHEN @HardFailed = 1 THEN N'E'
                    WHEN @Partial    = 1 THEN N'P'
                    ELSE N'C'
                END,
            received_rows           = ISNULL(@ReceivedRows, 0),
            total_orders            = ISNULL(@TotalOrders, 0),
            validation_valid_orders = ISNULL(@ValidationValidOrders, 0),
            validation_error_orders = ISNULL(@ValidationErrorOrders, 0),
            transferred_rows        = ISNULL(@TransferredRows, 0),
            processed_orders        = ISNULL(@ProcessedOrders, 0),
            process_error_orders    = ISNULL(@ProcessErrorOrders, 0),
            result_message          = LEFT(@Infobar, 1000),
            completed_date          = GETDATE(),
            UpdatedBy               = @RequestedBy,
            RecordDate              = GETDATE()
        WHERE SiteRef = @Site
          AND batch_id = @BatchId;

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        /*
            Unclassified failure. Customer Orders already committed by the
            Process loop before this point remain valid; batch_status = 'E'
            here means "the run did not finish", not "nothing was created".
            Verify with ue_SMK069_temp_sales_mst.process_status before re-running.
        */
        SET @Infobar = LEFT
        (
            N'[POS-999] CSV processing gagal '
            + CONVERT(NVARCHAR(20), ERROR_NUMBER())
            + N': '
            + ERROR_MESSAGE(),
            4000
        );

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            batch_status         = N'E',
            processed_orders     = ISNULL(@ProcessedOrders, 0),
            process_error_orders = ISNULL(@ProcessErrorOrders, 0),
            result_message       = LEFT(@Infobar, 1000),
            completed_date       = GETDATE(),
            UpdatedBy            = @RequestedBy,
            RecordDate           = GETDATE()
        WHERE SiteRef = @Site
          AND batch_id = @BatchId;

        RETURN 16;
    END CATCH;
END;
GO
