/* =============================================================================
   SMK069 - Multi-Error Response for POS Receive, Patch 04
   -----------------------------------------------------------------------------
   Object   : dbo.SMK069ReceivePosSalesJsonSp                (PATCHED)
   Date     : 2026-09-07
   Design   : docs/27-pos-receive-multi-error-response.md
   Depends  : dbo.SMK069ReceivePosSalesJsonCoreSp            (NOT MODIFIED)

   REQUEST
   -------
   POS team, 7 Sep 2026: one API call must report every invalid material, not
   the first one. Previously the integrator fixed one item, called again,
   discovered the next, and repeated.

   SCOPE
   -----
   This procedure only. `SMK069ReceivePosSalesJsonCoreSp` is NOT changed:
   the wrapper composes its message directly from
   ue_SMK069_pos_sales_inbound_mst, so Core's `TOP (10)` cap affects only
   Core's own @Infobar, which THROW discards anyway.

   SIGNATURE
   ---------
   Unchanged. All ten parameters keep their positions and types. No IDO method
   metadata change is required, and the Postman collection keeps working.

   WHAT CHANGED
   ------------
   1. `SELECT TOP (1)` for the message is replaced by a FOR XML PATH aggregate
      over every offending row. The friendly per-code descriptions (POS-102,
      POS-104, POS-105, POS-106 and the POS-101 fallback) are preserved exactly
      as they were — only the row count changes.

   2. Rows rejected solely by the atomic-order rule are excluded from the list
      whenever the same batch has at least one real error. Those rows carry
      `[POS-203] Order ditolak karena terdapat line lain yang tidak valid.` and
      are lines that are themselves fine; listing them would bury the materials
      the caller actually has to fix. If a batch somehow contains nothing but
      POS-203 rows, the filter is skipped so the response is never empty.

   3. The message is prefixed with the number of offending rows and is
      truncated with an explicit note when it exceeds the THROW limit.

   WHAT DELIBERATELY DID NOT CHANGE
   --------------------------------
   `THROW 51069` is kept. Business failure still surfaces to Mongoose as
   `Success: false` with the text in `Message`, exactly as today, so the POS
   integrator needs no change on their side to benefit from this patch.

   The consequence is unchanged too: THROW aborts the T-SQL batch, so
   `Parameters` and `ReturnValue` stay null and the counts
   (ReceivedRows / TotalOrders / ValidOrders / ErrorOrders / TransferredRows)
   still do not reach the caller, and the list is capped at the 2048-character
   THROW message limit — roughly a dozen materials.

   Lifting those two limits means replacing THROW with RETURN 16 and reading the
   result from `Parameters` instead of `Message`. That changes how the
   integrator detects failure, so it belongs in a separate patch agreed with the
   POS team first. See docs/27 §4 and §5.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069ReceivePosSalesJsonSp
    @SourceSystem    NVARCHAR(50) = N'POS',
    @BatchId         NVARCHAR(100),
    @PayloadJson     NVARCHAR(MAX),
    @ReceivedBy      UsernameType = NULL,
    @ReceivedRows    INT OUTPUT,
    @TotalOrders     INT OUTPUT,
    @ValidOrders     INT OUTPUT,
    @ErrorOrders     INT OUTPUT,
    @TransferredRows INT OUTPUT,
    @Infobar         InfobarType OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    -- ACTIVE SITE CONTEXT (SMK069 Site-Aware Hardening 2026-09-03)
    ----------------------------------------------------------------
    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    DECLARE
        @ReturnCode     INT,
        @HttpError      NVARCHAR(2048),
        @ErrorCode      NVARCHAR(20),
        @ErrorList      NVARCHAR(MAX)  = NULL,
        @ErrorRowCount  INT            = 0,
        @HasRealError   BIT            = 0,
        @NormSource     NVARCHAR(50)   = UPPER(LTRIM(RTRIM(@SourceSystem))),
        @NormBatch      NVARCHAR(100)  = LTRIM(RTRIM(@BatchId));

    EXEC @ReturnCode = dbo.SMK069ReceivePosSalesJsonCoreSp
        @SourceSystem    = @SourceSystem,
        @BatchId         = @BatchId,
        @PayloadJson     = @PayloadJson,
        @ReceivedBy      = @ReceivedBy,
        @ReceivedRows    = @ReceivedRows OUTPUT,
        @TotalOrders     = @TotalOrders OUTPUT,
        @ValidOrders     = @ValidOrders OUTPUT,
        @ErrorOrders     = @ErrorOrders OUTPUT,
        @TransferredRows = @TransferredRows OUTPUT,
        @Infobar         = @Infobar OUTPUT;

    /*
        Business failure must not be reported by Mongoose as a normal
        Success=true / HTTP 200 invocation.
    */
    IF ISNULL(@ReturnCode, 0) <> 0
       OR ISNULL(@ErrorOrders, 0) > 0
       OR ISNULL(@ValidOrders, 0) = 0
       OR ISNULL(@TransferredRows, 0) = 0
    BEGIN
        /* -------------------------------------------------------------------
           1. Result code — from the root error row, sibling messages last.
              UNCHANGED from the previous revision.
           ------------------------------------------------------------------- */
        SELECT TOP (1)
            @ErrorCode =
                CASE
                    /*
                        V2.4.8: extract the first stable code generically so a
                        newly introduced POS-xxx code is not silently collapsed
                        to POS-101 by the public wrapper.
                    */
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
                    ELSE N'POS-101'
                END
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
        WHERE e.SiteRef        = @Site
          AND e.source_system  = @NormSource
          AND e.batch_id       = @NormBatch
          AND e.inbound_status = N'E'
        ORDER BY
            CASE
                WHEN e.validation_msg LIKE N'Order memiliki line lain%'
                  OR LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) = N'[POS-203]'
                THEN 1
                ELSE 0
            END,
            e.row_no;

        /* -------------------------------------------------------------------
           2. NEW — does the batch contain any error that is not merely an
              atomic-order sibling rejection?
           ------------------------------------------------------------------- */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
            WHERE e.SiteRef        = @Site
              AND e.source_system  = @NormSource
              AND e.batch_id       = @NormBatch
              AND e.inbound_status = N'E'
              AND e.validation_msg NOT LIKE N'Order memiliki line lain%'
              AND LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) <> N'[POS-203]'
        )
            SET @HasRealError = 1;

        SELECT @ErrorRowCount = COUNT(*)
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
        WHERE e.SiteRef        = @Site
          AND e.source_system  = @NormSource
          AND e.batch_id       = @NormBatch
          AND e.inbound_status = N'E'
          AND
          (
              @HasRealError = 0
              OR
              (
                  e.validation_msg NOT LIKE N'Order memiliki line lain%'
                  AND LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) <> N'[POS-203]'
              )
          );

        /* -------------------------------------------------------------------
           3. NEW — every offending row, not just the first.
              The per-code descriptions are the previous revision's, verbatim.
           ------------------------------------------------------------------- */
        SELECT @ErrorList =
            STUFF
            (
                (
                    SELECT
                        N' | '
                        + CASE
                            WHEN NULLIF(LTRIM(RTRIM(e.cust_po)), N'') IS NULL
                            THEN N''
                            ELSE N'[cust_po=' + LTRIM(RTRIM(e.cust_po)) + N'] '
                          END
                        + CASE
                            WHEN e.validation_msg LIKE N'%Harga material%'
                            THEN
                                N'Harga material tidak ditemukan di Infor'
                                + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                + N', item=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''), N'<kosong>')
                                + N', u_m=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''), N'<kosong>')
                                + N', order_date=' + COALESCE(CONVERT(NVARCHAR(10), e.order_date, 23), N'<kosong>')
                                + N']'
                            WHEN e.validation_msg LIKE N'%Warehouse%'
                            THEN
                                N'Warehouse tidak valid di Infor'
                                + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                + N', whse=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''), N'<kosong>')
                                + N']'
                            WHEN e.validation_msg LIKE N'%U/M%'
                            THEN
                                N'U/M tidak valid di Infor'
                                + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                + N', item=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''), N'<kosong>')
                                + N', u_m=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''), N'<kosong>')
                                + N']'
                            WHEN e.validation_msg LIKE N'%Store/customer%'
                            THEN
                                N'Store/customer tidak terdaftar di Infor'
                                + N' [custnum=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cust_num))), N''), N'<kosong>')
                                + N']'
                            WHEN e.validation_msg LIKE N'%Material tidak terdaftar%'
                            THEN
                                N'Material tidak terdaftar di Infor'
                                + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                + N', item=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''), N'<kosong>')
                                + N']'
                            WHEN e.validation_msg LIKE N'Order memiliki line lain%'
                              OR LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) = N'[POS-203]'
                            THEN
                                N'Order ditolak karena terdapat line lain yang tidak valid'
                                + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                + N']'
                            ELSE
                                N'Data payload tidak terdaftar atau tidak sesuai di Infor'
                                + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                + N', custnum=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cust_num))), N''), N'<kosong>')
                                + N', item=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''), N'<kosong>')
                                + N', u_m=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''), N'<kosong>')
                                + N', whse=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''), N'<kosong>')
                                + N']'
                          END
                    FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                    WHERE e.SiteRef        = @Site
                      AND e.source_system  = @NormSource
                      AND e.batch_id       = @NormBatch
                      AND e.inbound_status = N'E'
                      AND
                      (
                          @HasRealError = 0
                          OR
                          (
                              e.validation_msg NOT LIKE N'Order memiliki line lain%'
                              AND LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) <> N'[POS-203]'
                          )
                      )
                    ORDER BY e.row_no
                    FOR XML PATH(N''), TYPE
                ).value(N'.', N'NVARCHAR(MAX)'),
                1,
                3,
                N''
            );

        IF NULLIF(@ErrorList, N'') IS NOT NULL
        BEGIN
            SET @HttpError = LEFT
            (
                N'[' + COALESCE(NULLIF(@ErrorCode, N''), N'POS-101') + N'] Request ditolak. '
                + CONVERT(NVARCHAR(20), @ErrorRowCount)
                + N' baris bermasalah: '
                + @ErrorList,
                1900
            );

            IF LEN
               (
                   N'[' + COALESCE(NULLIF(@ErrorCode, N''), N'POS-101') + N'] Request ditolak. '
                   + CONVERT(NVARCHAR(20), @ErrorRowCount)
                   + N' baris bermasalah: '
                   + @ErrorList
               ) > 1900
                SET @HttpError =
                    @HttpError
                    + N' ... (daftar dipotong; total '
                    + CONVERT(NVARCHAR(20), @ErrorRowCount)
                    + N' baris bermasalah)';
        END;

        /*
            V2.4.8 fallback for request-level errors that occur before an
            inbound row exists (for example POS-901, POS-012, POS-001).
            In that situation the queries above intentionally return nothing,
            therefore recover the stable code from the Core Infobar.
        */
        IF NULLIF(@ErrorCode, N'') IS NULL
           OR NULLIF(@HttpError, N'') IS NULL
        BEGIN
            DECLARE @InfoCodePos INT = CHARINDEX(N'[POS-', COALESCE(@Infobar, N''));
            IF @InfoCodePos > 0
               AND SUBSTRING(@Infobar, @InfoCodePos + 8, 1) = N']'
            BEGIN
                SET @ErrorCode = SUBSTRING(@Infobar, @InfoCodePos + 1, 7);
                SET @HttpError = LEFT(SUBSTRING(@Infobar, @InfoCodePos, 2048), 2048);
            END
            ELSE
            BEGIN
                SET @ErrorCode = N'POS-999';
                SET @HttpError = LEFT
                (
                    COALESCE
                    (
                        NULLIF(@Infobar, N''),
                        N'Request ditolak karena data payload tidak valid di Infor.'
                    ),
                    2048
                );
            END;
        END;

        SET @ErrorCode = COALESCE(NULLIF(@ErrorCode, N''), N'POS-999');

        /* Row-level friendly errors do not yet contain the prefix. */
        IF LEFT(LTRIM(COALESCE(@HttpError, N'')), 5) <> N'[POS-'
        BEGIN
            SET @HttpError =
                N'[' + @ErrorCode + N'] '
                + COALESCE
                  (
                      NULLIF(@HttpError, N''),
                      N'Request ditolak karena data payload tidak valid di Infor.'
                  );
        END;

        SET @HttpError = LEFT(@HttpError, 2048);

        THROW 51069, @HttpError, 1;
    END;

    RETURN 0;
END;
GO
