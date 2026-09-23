/* =============================================================================
   SMK069 - Patch 35 - Peak Season must be set before mapping-view snapshot
   -----------------------------------------------------------------------------
   Date    : 2026-09-23
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY
   Object  : dbo.SMK069ReceivePosSalesJsonCoreSp

   PROVEN UAT DEFECT
   -----------------
   Payload DEV4-271:
     item AC20002B qty 340 PCS is_peak_season=1
     item AC20003B qty 110 PCS is_peak_season=1

   Current mapping view for the same inbound rows resolves Peak mapping:
     AC20042 / 17 TRY / 76000
     AC20043 / 11 TRY / 76000

   But temp/CO created:
     AC20002 / 22.66667 TRY / 57000
     AC20003 / 13.75 TRY / 60800

   ROOT CAUSE
   ----------
   Public dbo.SMK069ReceivePosSalesJsonSp called Core FIRST and only afterwards
   propagated is_peak_season from payload into inbound/temp (Patch 27).

   Therefore, while Core created #MapView, inbound.is_peak_season was still its
   default 0. The mapping view resolved Normal mapping even though payload sent 1.

   FIX
   ---
   Core now reads $.is_peak_season from each raw_json row and persists it into
   ue_SMK069_pos_sales_inbound_mst BEFORE section 3 materializes #MapView.

   The existing post-Core wrapper propagation remains as a defensive/temp sync,
   but it is no longer responsible for the business mapping decision.

   Apply Database compatible: one executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
    THROW 510350, N'[PATCH-35] inbound table tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'is_peak_season') IS NULL
    THROW 510351, N'[PATCH-35] inbound.is_peak_season belum tersedia.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'V') IS NULL
    THROW 510352, N'[PATCH-35] mapping view tidak ditemukan.', 1;

/* Redeploy corrected canonical Core. */
DECLARE @Patch35CoreSql NVARCHAR(MAX) = N'';
SET @Patch35CoreSql = @Patch35CoreSql + N'CREATE OR ALTER PROCEDURE dbo.SMK069ReceivePosSalesJsonCoreSp
    @SourceSystem    NVARCHAR(50) = N''POS'',
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
    SET XACT_ABORT OFF;

    ----------------------------------------------------------------
    -- ACTIVE SITE CONTEXT (SMK069 Site-Aware Hardening 2026-09-03)
    ----------------------------------------------------------------
    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;


    DECLARE
        @InitialTranCount INT = @@TRANCOUNT,
        @SavepointName SYSNAME = N''SMK069ReceiveV240'',
        @ErrorDetail NVARCHAR(2800);

    SET @SourceSystem = UPPER(LTRIM(RTRIM(@SourceSystem)));
    SET @BatchId = LTRIM(RTRIM(@BatchId));

    SET @ReceivedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ReceivedBy)), N''''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ReceivedRows = 0;
    SET @TotalOrders = 0;
    SET @ValidOrders = 0;
    SET @ErrorOrders = 0;
    SET @TransferredRows = 0;
    SET @Infobar = NULL;

    IF NULLIF(LTRIM(RTRIM(@Site)), N'''') IS NULL
    BEGIN
        SET @Infobar = N''[POS-901] Active Site tidak ditemukan dari CONTEXT_INFO().'';
        RETURN 16;
    END;


    IF NULLIF(@SourceSystem, N'''') IS NULL
    BEGIN
        SET @Infobar = N''[POS-901] SourceSystem wajib diisi.'';
        RETURN 16;
    END;

    IF NULLIF(@BatchId, N'''') IS NULL
    BEGIN
        SET @Infobar = N''[POS-012] batch_id wajib diisi.'';
        RETURN 16;
    END;

    IF ISJSON(@PayloadJson) <> 1
       OR LEFT(LTRIM(@PayloadJson), 1) <> N''[''
    BEGIN
        SET @Infobar = N''[POS-001] Payload JSON harus berupa array JSON yang valid.'';
        RETURN 16;
    END;

    /* =============================================================
       Batch idempotency
       ============================================================= */
    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId
    )
    BEGIN
        SELECT
            @ReceivedRows = COUNT(*),
            @TotalOrders = COUNT
            (
                DISTINCT NULLIF(LTRIM(RTRIM(cust_po)), N'''')
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId;

        SELECT
            @ValidOrders = COUNT
            (
                DISTINCT CASE
                    WHEN inbound_status = N''T''
                    THEN NULLIF(LTRIM(RTRIM(cust_po)), N'''')
                END
            ),
            @ErrorOrders = COUN';
SET @Patch35CoreSql = @Patch35CoreSql + N'T
            (
                DISTINCT CASE
                    WHEN inbound_status = N''E''
                    THEN NULLIF(LTRIM(RTRIM(cust_po)), N'''')
                END
            ),
            @TransferredRows = ISNULL
            (
                SUM(CASE WHEN inbound_status = N''T'' THEN 1 ELSE 0 END),
                0
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId;

        SET @ErrorDetail = NULL;

        SELECT
            @ErrorDetail =
                STUFF
                (
                    (
                        SELECT TOP (10)
                            N'' | ''
                            + CASE
                                  WHEN NULLIF(LTRIM(RTRIM(e.cust_po)), N'''') IS NULL
                                  THEN N''''
                                  ELSE N''cust_po=''
                                     + LTRIM(RTRIM(e.cust_po))
                                     + N'', ''
                              END
                            + N''coline=''
                            + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                            + N'': ''
                            + CASE
                                WHEN e.validation_msg LIKE N''%mapping view tidak menghasilkan row%''
                                  OR e.validation_msg LIKE N''%inbound_id%''
                                THEN
                                    N''[POS-101] Data payload tidak terdaftar atau tidak sesuai di Infor''
                                    + N'' [custnum=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cust_num))), N''''), N''<kosong>'')
                                    + N'', item=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'', u_m=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''''), N''<kosong>'')
                                    + N'', whse=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''Order memiliki line lain%''
                                THEN N''[POS-203] Order ditolak karena terdapat line lain pada cust_po yang tidak valid.''
                                ELSE COALESCE
                                (
                                    NULLIF(LTRIM(RTRIM(e.validation_msg)), N''''),
                                    N''Data payload tidak valid.''
                                )
                              END
                        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                        WHERE e.SiteRef = @Site
                          AND e.source_system = @SourceSystem
              ';
SET @Patch35CoreSql = @Patch35CoreSql + N'            AND e.batch_id = @BatchId
                          AND e.inbound_status = N''E''
                        ORDER BY e.row_no
                        FOR XML PATH(N''''), TYPE
                    ).value(N''.'', N''NVARCHAR(MAX)''),
                    1,
                    3,
                    N''''
                );

        SET @Infobar =
            LEFT
            (
                N''[POS-000] Batch '' + @BatchId
                + N'' diterima. Row: '' + CONVERT(NVARCHAR(20), @ReceivedRows)
                + N''; order(cust_po): '' + CONVERT(NVARCHAR(20), @TotalOrders)
                + N''; valid: '' + CONVERT(NVARCHAR(20), @ValidOrders)
                + N''; error: '' + CONVERT(NVARCHAR(20), @ErrorOrders)
                + N''; row masuk temp: '' + CONVERT(NVARCHAR(20), @TransferredRows)
                + N''.''
                + CASE
                      WHEN @ErrorOrders > 0
                       AND NULLIF(@ErrorDetail, N'''') IS NOT NULL
                      THEN N'' ErrorDetail: '' + @ErrorDetail
                      ELSE N''''
                  END,
                4000
            );

        /*
            Idempotent replay returns the SAME business result as the first call.
            Do not add a second "already received/processed" error to the
            business response.
        */
        IF ISNULL(@ErrorOrders, 0) > 0
           OR ISNULL(@ValidOrders, 0) = 0
           OR ISNULL(@TransferredRows, 0) = 0
            RETURN 16;

        RETURN 0;
    END;

    BEGIN TRY
        IF @InitialTranCount = 0
            BEGIN TRANSACTION;
        ELSE
            SAVE TRANSACTION SMK069ReceiveV240;

        /* =============================================================
           1. Preserve raw JSON
           ============================================================= */
        INSERT INTO dbo.ue_SMK069_pos_sales_inbound_mst
        (
            SiteRef,
            source_system,
            batch_id,
            row_no,
            raw_json,
            inbound_status,
            created_by,
            updated_by
        )
        SELECT
            @Site,
            @SourceSystem,
            @BatchId,
            TRY_CONVERT(INT, j.[key]) + 1,
            j.[value],
            N''R'',
            @ReceivedBy,
            @ReceivedBy
        FROM OPENJSON(@PayloadJson) AS j
        WHERE j.[type] = 5;

        SET @ReceivedRows = @@ROWCOUNT;

        IF @ReceivedRows = 0
            THROW 50101, N''[POS-001] Payload tidak memiliki transaksi.'', 1;

        /* =============================================================
           2. Dynamic external-to-canonical raw field extraction
           ============================================================= */
        SELECT
            i.inbound_id,
            m.target_field,
            NULLIF
            (
                LTRIM(RTRIM(CONVERT(NVARCHAR(4000), p.[value]))),
                N''''
            ) AS field_value,
            ROW_NUMBER() OVER
            (
            ';
SET @Patch35CoreSql = @Patch35CoreSql + N'    PARTITION BY i.inbound_id, m.target_field
                ORDER BY m.priority_no, p.[key]
            ) AS mapping_rank
        INTO #Mapped
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        CROSS APPLY OPENJSON(i.raw_json) AS p
        INNER JOIN dbo.ue_SMK069_pos_field_map_mst AS m
          ON m.SiteRef = @Site
         AND m.source_system = @SourceSystem
         AND m.source_field =
             LOWER(LTRIM(RTRIM(p.[key] COLLATE DATABASE_DEFAULT)))
         AND m.is_active = 1
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        SELECT
            i.inbound_id,
            MAX(CASE WHEN m.target_field = N''SiteRef''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS SiteRefRaw,
            MAX(CASE WHEN m.target_field = N''cust_num''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS CustNumRaw,
            MAX(CASE WHEN m.target_field = N''order_date''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS OrderDateRaw,
            MAX(CASE WHEN m.target_field = N''cust_po''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS CustPoRaw,
            MAX(CASE WHEN m.target_field = N''co_line''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS CoLineRaw,
            MAX(CASE WHEN m.target_field = N''item''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS ItemRaw,
            MAX(CASE WHEN m.target_field = N''qty_ordered''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS QtyRaw,
            MAX(CASE WHEN m.target_field = N''whse''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS WhseRaw,
            MAX(CASE WHEN m.target_field = N''due_date''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS DueDateRaw,
            MAX(CASE WHEN m.target_field = N''u_m''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS UMRaw,
            MAX(CASE WHEN m.target_field = N''terms_code''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS TermsRaw,
            MAX(CASE WHEN m.target_field = N''tax_code1''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS TaxRaw,
            MAX(CASE WHEN m.target_field = N''exch_rate''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS ExchRateRaw
        INTO #Normalized
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        LEFT JOIN #Mapped AS m
          ON m.inbound_id = i.inbound_id
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
        GROUP BY i.inbound_id;

        IF EXISTS
        (
            SELECT 1
            FROM #Normalized AS n
            WHERE NULLIF(LTRIM(RTRIM(n.SiteRefRaw)), N'''') IS NOT NULL
              AND UPPER(LTRIM(RTRIM(n.SiteRefRaw))) COLLATE DATABASE_DEFAULT
                  <> UPPER(LTRIM(RTRIM(CONVERT(';
SET @Patch35CoreSql = @Patch35CoreSql + N'NVARCHAR(16), @Site)))) COLLATE DATABASE_DEFAULT
        )
        BEGIN
            THROW 50109, N''[POS-901] SiteRef payload tidak sesuai dengan Active Site.'', 1;
        END;

        UPDATE i
        SET
            SiteRef = @Site,
            cust_num = LEFT(n.CustNumRaw, 20),
            order_date = TRY_CONVERT(DATE, n.OrderDateRaw),
            cust_po = LEFT(n.CustPoRaw, 25),
            co_num = NULL,
            co_line = TRY_CONVERT(INT, n.CoLineRaw),
            item = LEFT(n.ItemRaw, 50),
            qty_ordered = TRY_CONVERT(DECIMAL(18,8), n.QtyRaw),
            unit_price = NULL,
            whse = LEFT(n.WhseRaw, 20),
            due_date = COALESCE
            (
                TRY_CONVERT(DATE, n.DueDateRaw),
                TRY_CONVERT(DATE, n.OrderDateRaw)
            ),
            u_m = LEFT(n.UMRaw, 20),
            terms_code = LEFT(n.TermsRaw, 20),
            tax_code1 = LEFT(n.TaxRaw, 20),
            exch_rate = COALESCE
            (
                TRY_CONVERT(DECIMAL(18,8), n.ExchRateRaw),
                CONVERT(DECIMAL(18,8), 1)
            ),
            /*
                Peak Season MUST be persisted before #MapView is materialized.
                The canonical mapping view uses inbound.is_peak_season to select
                the correct customer-item/U/M mapping.  Previously the public
                wrapper populated this flag only AFTER Core returned, which
                made Peak payloads map as Normal during Core processing.
            */
            is_peak_season =
                CASE
                    WHEN TRY_CONVERT(INT, JSON_VALUE(i.raw_json, ''$.is_peak_season'')) = 1
                    THEN 1
                    ELSE 0
                END,
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #Normalized AS n
          ON n.inbound_id = i.inbound_id;

        /* =============================================================
           3. Snapshot BUSINESS SOURCE from mapping view
           ============================================================= */
        SELECT
            v.inbound_id,
            v.source_system,
            v.batch_id,
            v.row_no,
            v.SiteRef,
            v.cust_num,
            v.cust_seq,
            v.cust_po,
            v.order_date,
            v.co_num,
            v.co_line,
            v.item,
            v.qty_ordered,
            v.unit_price,
            v.whse,
            v.due_date,
            v.u_m,
            v.terms_code,
            v.tax_code1,
            v.exch_rate,
            COUNT(*) OVER (PARTITION BY v.inbound_id) AS view_row_count,
            ROW_NUMBER() OVER
            (
                PARTITION BY v.inbound_id
                ORDER BY v.cust_num, v.cust_seq, v.item
            ) AS view_rn
        INTO #MapView
        FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
        WHERE v.SiteRef = @Site
          AND v.source_system = @SourceSystem
  ';
SET @Patch35CoreSql = @Patch35CoreSql + N'        AND v.batch_id = @BatchId;

        /* =============================================================
           4. Validate mapping-view result
           ============================================================= */
        ;WITH ViewAgg AS
        (
            SELECT
                inbound_id,
                MAX(view_row_count) AS view_row_count,
                MAX(CASE WHEN view_rn = 1 THEN SiteRef END) AS SiteRef,
                MAX(CASE WHEN view_rn = 1 THEN cust_num END) AS cust_num,
                MAX(CASE WHEN view_rn = 1 THEN cust_seq END) AS cust_seq,
                MAX(CASE WHEN view_rn = 1 THEN cust_po END) AS cust_po,
                MAX(CASE WHEN view_rn = 1 THEN order_date END) AS order_date,
                MAX(CASE WHEN view_rn = 1 THEN co_line END) AS co_line,
                MAX(CASE WHEN view_rn = 1 THEN item END) AS item,
                MAX(CASE WHEN view_rn = 1 THEN qty_ordered END) AS qty_ordered,
                MAX(CASE WHEN view_rn = 1 THEN unit_price END) AS unit_price,
                MAX(CASE WHEN view_rn = 1 THEN whse END) AS whse,
                MAX(CASE WHEN view_rn = 1 THEN u_m END) AS u_m,
                MAX(CASE WHEN view_rn = 1 THEN exch_rate END) AS exch_rate
            FROM #MapView
            GROUP BY inbound_id
        )
        UPDATE i
        SET
            validation_msg =
                NULLIF
                (
                    STUFF
                    (
                        CONCAT
                        (
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 0
                                THEN
                                    N''; [POS-101] Data payload tidak terdaftar atau tidak sesuai di Infor''
                                    + N'' [custnum=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), i.cust_num))), N''''), N''<kosong>'')
                                    + N'', item=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.item))), N''''), N''<kosong>'')
                                    + N'', u_m=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.u_m))), N''''), N''<kosong>'')
                                    + N'', whse=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.whse))), N''''), N''<kosong>'')
                                    + N'', coline=''
                                    + COALESCE(CONVERT(NVARCHAR(20), i.co_line), N''<kosong>'')
                                    + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) > 1
                                THEN N''; mapping view menghasilkan lebih dari satu row untuk inbound_id yang sama''
                                ELSE N''''
                            END,
                   ';
SET @Patch35CoreSql = @Patch35CoreSql + N'         CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))), N'''') IS NULL
                                THEN N''; [POS-101] Site tidak valid di Infor''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.cust_num))), N'''') IS NULL
                                THEN N''; [POS-102] Store/customer tidak terdaftar di Infor [custnum='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), i.cust_num))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND v.cust_seq IS NULL
                                THEN N''; [POS-107] Store/customer sequence tidak ditemukan di Infor [custnum='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), i.cust_num))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))), N'''') IS NULL
                                THEN N''; [POS-004] cust_po wajib diisi''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND v.order_date IS NULL
                                THEN N''; [POS-003] order_date wajib diisi''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND ISNULL(v.co_line, 0) <= 0
                                THEN N''; [POS-006] coline harus lebih besar dari 0''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.item))), N'''') IS NULL
                                THEN N''; [POS-103] Material tidak terdaftar di Infor [item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.item))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND ISNULL(v.qty_ordered, 0) <= 0
                                THEN N''; [POS-008] qty_ordered harus lebih besar dari 0''
                                ELSE N''''
';
SET @Patch35CoreSql = @Patch35CoreSql + N'                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND v.unit_price IS NULL
                                THEN N''; [POS-105] Harga material tidak ditemukan di Infor [item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.item))), N''''), N''<kosong>'') + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.u_m))), N''''), N''<kosong>'') + N'', order_date='' + COALESCE(CONVERT(NVARCHAR(10), i.order_date, 23), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), v.whse))), N'''') IS NULL
                                THEN N''; [POS-106] Warehouse tidak valid di Infor [whse='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.whse))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), v.u_m))), N'''') IS NULL
                                THEN N''; [POS-104] U/M tidak valid di Infor [item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.item))), N''''), N''<kosong>'') + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.u_m))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND ISNULL(v.exch_rate, 0) <= 0
                                THEN N''; [POS-010] exch_rate harus lebih besar dari 0''
                                ELSE N''''
                            END
                        ),
                        1,
                        2,
                        N''''
                    ),
                    N''''
                ),
            inbound_status =
                CASE
                    WHEN ISNULL(v.view_row_count, 0) <> 1
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))), N'''') IS NULL
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.cust_num))), N'''') IS NULL
                      OR v.cust_seq IS NULL
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))), N'''') IS NULL
                      OR v.order_date IS NULL
                      OR ISNULL(v.co_line, 0) <= 0
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.item))), N'''') IS NULL
                      OR ISNULL(v.qty_ordered, 0) <= 0
                      OR v.unit_price IS NULL
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), v.whse))), N'''') IS NULL
                      OR NULLIF(LTRIM(RTRIM(CONVERT(';
SET @Patch35CoreSql = @Patch35CoreSql + N'NVARCHAR(80), v.u_m))), N'''') IS NULL
                      OR ISNULL(v.exch_rate, 0) <= 0
                    THEN N''E''
                    ELSE N''V''
                END,
            validated_date = GETDATE(),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        LEFT JOIN ViewAgg AS v
          ON v.inbound_id = i.inbound_id
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        /* =============================================================
           5. Duplicate co_line from mapping view
           ============================================================= */
        ;WITH D AS
        (
            SELECT
                SiteRef,
                cust_po,
                co_line
            FROM #MapView
            WHERE view_rn = 1
              AND view_row_count = 1
            GROUP BY SiteRef, cust_po, co_line
            HAVING COUNT(*) > 1
        )
        UPDATE i
        SET
            inbound_status = N''E'',
            validation_msg = LEFT
            (
                CONCAT
                (
                    NULLIF(i.validation_msg, N''''),
                    CASE WHEN NULLIF(i.validation_msg, N'''') IS NULL THEN N'''' ELSE N''; '' END,
                    N''[POS-201] coline duplikat dalam cust_po yang sama''
                ),
                1000
            ),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        INNER JOIN D
          ON D.SiteRef = v.SiteRef
         AND D.cust_po = v.cust_po
         AND D.co_line = v.co_line
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        /* =============================================================
           6. Header consistency from mapping view
           ============================================================= */
        ;WITH H AS
        (
            SELECT
                SiteRef,
                cust_po,
                COUNT(DISTINCT ISNULL(CONVERT(NVARCHAR(40), cust_num), N''<NULL>'')) AS cust_count,
                COUNT(DISTINCT ISNULL(CONVERT(NVARCHAR(20), cust_seq), N''<NULL>'')) AS seq_count,
                COUNT(DISTINCT ISNULL(CONVERT(NVARCHAR(80), whse), N''<NULL>'')) AS whse_count,
                COUNT(DISTINCT ISNULL(CONVERT(NVARCHAR(30), order_date, 126), N''<NULL>'')) AS date_count
            FROM #MapView
            WHERE view_rn = 1
              AND view_row_count = 1
            GROUP BY SiteRef, cust_po
        ),
        BadHeader AS
        (
            SELECT SiteRef, cust_po
            FROM H
            WHERE cust_count > 1
               OR seq_count > 1
               OR whse_count > 1
               OR date_count > 1
        )
        UPDATE i
        SET
            inbound_statu';
SET @Patch35CoreSql = @Patch35CoreSql + N's = N''E'',
            validation_msg = LEFT
            (
                CONCAT
                (
                    NULLIF(i.validation_msg, N''''),
                    CASE WHEN NULLIF(i.validation_msg, N'''') IS NULL THEN N'''' ELSE N''; '' END,
                    N''[POS-202] Data header tidak konsisten dalam satu cust_po''
                ),
                1000
            ),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        INNER JOIN BadHeader AS b
          ON b.SiteRef = v.SiteRef
         AND b.cust_po = v.cust_po
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        /* =============================================================
           7. Duplicate business order protection - mapped values only
           ============================================================= */
        UPDATE i
        SET
            inbound_status = N''E'',
            validation_msg = LEFT
            (
                CONCAT
                (
                    NULLIF(i.validation_msg, N''''),
                    CASE WHEN NULLIF(i.validation_msg, N'''') IS NULL THEN N'''' ELSE N''; '' END,
                    N''[POS-204] cust_po sudah sedang/ pernah diproses''
                ),
                1000
            ),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V''
          AND EXISTS
          (
              SELECT 1
              FROM dbo.ue_SMK069_temp_sales_mst AS t
              WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), t.SiteRef))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                        COLLATE DATABASE_DEFAULT
                AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                        COLLATE DATABASE_DEFAULT
          );

        UPDATE i
        SET
            inbound_status = N''E'',
            validation_msg = LEFT
            (
                CONCAT
                (
                    NULLIF(i.validation_msg, N''''),
                    CASE WHEN NULLIF(i.validation_msg, N'''') IS NULL THEN N'''' ELSE N''; '' END,
                    N''[POS-204] cust_po sudah pernah dibuat menjadi Customer Order''
                ),
                1000
            ),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
       ';
SET @Patch35CoreSql = @Patch35CoreSql + N' INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V''
          AND EXISTS
          (
              SELECT 1
              FROM dbo.co_mst AS c
              WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), c.site_ref))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                        COLLATE DATABASE_DEFAULT
                AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), c.cust_po))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                        COLLATE DATABASE_DEFAULT
                AND c.[type] = N''B''
          );

        /* =============================================================
           8. Atomic order rule
           ============================================================= */
        ;WITH BadRawOrder AS
        (
            SELECT DISTINCT
                i.SiteRef,
                i.cust_po
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.source_system = @SourceSystem
              AND i.batch_id = @BatchId
              AND i.inbound_status = N''E''
              AND NULLIF(LTRIM(RTRIM(i.cust_po)), N'''') IS NOT NULL
        )
        UPDATE i
        SET
            inbound_status = N''E'',
            validation_msg =
                CASE
                    WHEN NULLIF(i.validation_msg, N'''') IS NULL
                    THEN N''[POS-203] Order ditolak karena terdapat line lain yang tidak valid.''
                    ELSE i.validation_msg
                END,
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN BadRawOrder AS b
          ON b.SiteRef = i.SiteRef
         AND b.cust_po = i.cust_po
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        /* =============================================================
           9. Generate co_num per valid mapped SiteRef + cust_po
           ============================================================= */
        CREATE TABLE #GeneratedOrders
        (
            SiteRef NVARCHAR(16) NOT NULL,
            cust_po NVARCHAR(100) NOT NULL,
            order_date DATE NOT NULL,
            co_num NVARCHAR(30) NOT NULL,
            PRIMARY KEY (SiteRef, cust_po)
        );

        DECLARE
            @OrderSiteRef NVARCHAR(16),
            @OrderCustPo NVARCHAR(100),
            @OrderDate DATE,
            @OrderPrefix NVARCHAR(10) = N''R'',
            @Prefix NVARCHAR(20),
            @NewCoNum NVARCHAR(30),
            @NextNo INT,
            @MaxNo INT,
            @LockResult INT,
            @LockResource NVARCHAR(255);

        DECLARE Va';
SET @Patch35CoreSql = @Patch35CoreSql + N'lidOrderCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            v.SiteRef,
            v.cust_po,
            MIN(v.order_date)
        FROM #MapView AS v
        INNER JOIN dbo.ue_SMK069_pos_sales_inbound_mst AS i
          ON i.inbound_id = v.inbound_id
        WHERE v.view_rn = 1
          AND v.view_row_count = 1
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V''
        GROUP BY v.SiteRef, v.cust_po;

        OPEN ValidOrderCursor;

        FETCH NEXT FROM ValidOrderCursor
        INTO @OrderSiteRef, @OrderCustPo, @OrderDate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Prefix = @OrderPrefix + CONVERT(CHAR(4), @OrderDate, 12);
            SET @LockResource =
                N''SMK069_CONUM|''
                + LTRIM(RTRIM(@OrderSiteRef))
                + N''|''
                + @Prefix;

            EXEC @LockResult = sys.sp_getapplock
                @Resource = @LockResource,
                @LockMode = N''Exclusive'',
                @LockOwner = N''Transaction'',
                @LockTimeout = 15000;

            IF @LockResult < 0
                THROW 50120, N''[POS-901] Gagal memperoleh nomor Customer Order.'', 1;

            SELECT
                @MaxNo = ISNULL(MAX(x.run_no), 0)
            FROM
            (
                SELECT TRY_CONVERT(INT, RIGHT(LTRIM(RTRIM(c.co_num)), 5)) AS run_no
                FROM dbo.co_mst AS c
                WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), c.site_ref))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(@OrderSiteRef)))
                        COLLATE DATABASE_DEFAULT
                  AND LTRIM(RTRIM(c.co_num)) LIKE @Prefix + N''%''
                  AND LEN(LTRIM(RTRIM(c.co_num))) = LEN(@Prefix) + 5

                UNION ALL

                SELECT TRY_CONVERT(INT, RIGHT(LTRIM(RTRIM(t.co_num)), 5))
                FROM dbo.ue_SMK069_temp_sales_mst AS t
                WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), t.SiteRef))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(@OrderSiteRef)))
                        COLLATE DATABASE_DEFAULT
                  AND LTRIM(RTRIM(t.co_num)) LIKE @Prefix + N''%''
                  AND LEN(LTRIM(RTRIM(t.co_num))) = LEN(@Prefix) + 5

                UNION ALL

                SELECT TRY_CONVERT(INT, RIGHT(g.co_num, 5))
                FROM #GeneratedOrders AS g
                WHERE UPPER(LTRIM(RTRIM(g.SiteRef)))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(@OrderSiteRef)))
                        COLLATE DATABASE_DEFAULT
                  AND g.co_num LIKE @Prefix + N''%''
            ) AS x
            WHERE x.run_no IS NOT NULL;

            SET @NextNo = ISNULL(@MaxNo, 0) + 1;

            IF @NextNo > 99999
                THROW 50121, N''[POS-901] Running number Customer Order untuk periode tersebut sudah penuh.'', 1;

            S';
SET @Patch35CoreSql = @Patch35CoreSql + N'ET @NewCoNum =
                @Prefix
                + RIGHT(N''00000'' + CONVERT(NVARCHAR(10), @NextNo), 5);

            IF LEN(@NewCoNum) > 10
                THROW 50122, N''[POS-901] Format nomor Customer Order melebihi batas yang diperbolehkan.'', 1;

            INSERT INTO #GeneratedOrders
            (
                SiteRef,
                cust_po,
                order_date,
                co_num
            )
            VALUES
            (
                @OrderSiteRef,
                @OrderCustPo,
                @OrderDate,
                @NewCoNum
            );

            UPDATE i
            SET
                co_num = @NewCoNum,
                updated_by = @ReceivedBy
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            INNER JOIN #MapView AS v
              ON v.inbound_id = i.inbound_id
             AND v.view_rn = 1
             AND v.view_row_count = 1
            WHERE i.source_system = @SourceSystem
              AND i.batch_id = @BatchId
              AND i.inbound_status = N''V''
              AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                    COLLATE DATABASE_DEFAULT
                  = UPPER(LTRIM(RTRIM(@OrderSiteRef)))
                    COLLATE DATABASE_DEFAULT
              AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                    COLLATE DATABASE_DEFAULT
                  = UPPER(LTRIM(RTRIM(@OrderCustPo)))
                    COLLATE DATABASE_DEFAULT;

            FETCH NEXT FROM ValidOrderCursor
            INTO @OrderSiteRef, @OrderCustPo, @OrderDate;
        END;

        CLOSE ValidOrderCursor;
        DEALLOCATE ValidOrderCursor;

        /* =============================================================
          10. Refresh BUSINESS SOURCE after generated co_num
           ============================================================= */
        DELETE FROM #MapView;

        INSERT INTO #MapView
        (
            inbound_id,
            source_system,
            batch_id,
            row_no,
            SiteRef,
            cust_num,
            cust_seq,
            cust_po,
            order_date,
            co_num,
            co_line,
            item,
            qty_ordered,
            unit_price,
            whse,
            due_date,
            u_m,
            terms_code,
            tax_code1,
            exch_rate,
            view_row_count,
            view_rn
        )
        SELECT
            v.inbound_id,
            v.source_system,
            v.batch_id,
            v.row_no,
            v.SiteRef,
            v.cust_num,
            v.cust_seq,
            v.cust_po,
            v.order_date,
            v.co_num,
            v.co_line,
            v.item,
            v.qty_ordered,
            v.unit_price,
            v.whse,
            v.due_date,
            v.u_m,
            v.terms_code,
            v.tax_code1,
            v.exch_rate,
            COUNT(*) OVER (PARTITION BY v.inbound_id),
        ';
SET @Patch35CoreSql = @Patch35CoreSql + N'    ROW_NUMBER() OVER
            (
                PARTITION BY v.inbound_id
                ORDER BY v.cust_num, v.cust_seq, v.item
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
        WHERE v.SiteRef = @Site
          AND v.source_system = @SourceSystem
          AND v.batch_id = @BatchId;

        /* =============================================================
          11. Transfer to temp - 100% from mapping view
           ============================================================= */
        INSERT INTO dbo.ue_SMK069_temp_sales_mst
        (
            SiteRef,
            cust_num,
            order_date,
            terms_code,
            co_num,
            cust_po,
            co_line,
            unit_price,
            tax_code1,
            exch_rate,
            whse,
            item,
            qty_ordered,
            due_date,
            u_m,
            process_status,
            validation_msg,
            error_msg,
            retry_count
        )
        SELECT
            v.SiteRef,
            v.cust_num,
            v.order_date,
            v.terms_code,
            v.co_num,
            v.cust_po,
            v.co_line,
            v.unit_price,
            v.tax_code1,
            v.exch_rate,
            v.whse,
            v.item,
            v.qty_ordered,
            COALESCE(v.due_date, v.order_date),
            v.u_m,
            N''V'',
            NULL,
            NULL,
            0
        FROM #MapView AS v
        INNER JOIN dbo.ue_SMK069_pos_sales_inbound_mst AS i
          ON i.inbound_id = v.inbound_id
        WHERE v.view_rn = 1
          AND v.view_row_count = 1
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V'';

        SET @TransferredRows = @@ROWCOUNT;

        /* =============================================================
          12. Verify temp persistence from mapping-view keys
           ============================================================= */
        IF EXISTS
        (
            SELECT 1
            FROM #MapView AS v
            INNER JOIN dbo.ue_SMK069_pos_sales_inbound_mst AS i
              ON i.inbound_id = v.inbound_id
            WHERE v.view_rn = 1
              AND v.view_row_count = 1
              AND i.source_system = @SourceSystem
              AND i.batch_id = @BatchId
              AND i.inbound_status = N''V''
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.ue_SMK069_temp_sales_mst AS t
                  WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), t.SiteRef))))
                            COLLATE DATABASE_DEFAULT
                        = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                            COLLATE DATABASE_DEFAULT
                    AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num))))
                            COLLATE DATABASE_DEFAULT
                        = UPPER';
SET @Patch35CoreSql = @Patch35CoreSql + N'(LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num))))
                            COLLATE DATABASE_DEFAULT
                    AND t.co_line = v.co_line
                    AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))))
                            COLLATE DATABASE_DEFAULT
                        = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                            COLLATE DATABASE_DEFAULT
              )
        )
            THROW 50130, N''[POS-902] Data valid gagal dipindahkan ke proses Customer Order.'', 1;

        UPDATE i
        SET
            inbound_status = N''T'',
            transferred_date = GETDATE(),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V'';

        /* =============================================================
          13. Final counts + Infobar
           ============================================================= */
        SELECT
            @TotalOrders = COUNT
            (
                DISTINCT NULLIF(LTRIM(RTRIM(cust_po)), N'''')
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId;

        SELECT
            @ValidOrders = COUNT
            (
                DISTINCT CASE
                    WHEN inbound_status = N''T''
                    THEN NULLIF(LTRIM(RTRIM(cust_po)), N'''')
                END
            ),
            @ErrorOrders = COUNT
            (
                DISTINCT CASE
                    WHEN inbound_status = N''E''
                    THEN NULLIF(LTRIM(RTRIM(cust_po)), N'''')
                END
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId;

        SET @ErrorDetail = NULL;

        SELECT
            @ErrorDetail =
                STUFF
                (
                    (
                        SELECT TOP (10)
                            N'' | Row ''
                            + CONVERT(NVARCHAR(20), e.row_no)
                            + CASE
                                  WHEN NULLIF(LTRIM(RTRIM(e.cust_po)), N'''') IS NULL
                                  THEN N''''
                                  ELSE N'' [cust_po=''
                                     + LTRIM(RTRIM(e.cust_po))
                                     + N'']''
                              END
                            + N'': ''
                            + COALESCE
                              (
                                  NULLIF(LTRIM(RTRIM(e.validation_msg)), N''''),
                                  N''Validation error.''
         ';
SET @Patch35CoreSql = @Patch35CoreSql + N'                     )
                        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                        WHERE e.SiteRef = @Site
                          AND e.source_system = @SourceSystem
                          AND e.batch_id = @BatchId
                          AND e.inbound_status = N''E''
                        ORDER BY e.row_no
                        FOR XML PATH(N''''), TYPE
                    ).value(N''.'', N''NVARCHAR(MAX)''),
                    1,
                    3,
                    N''''
                );

        SET @Infobar =
            LEFT
            (
                N''[POS-000] Batch '' + @BatchId
                + N'' diterima. Row: '' + CONVERT(NVARCHAR(20), @ReceivedRows)
                + N''; order(cust_po): 1''
                + N''; valid: '' + CONVERT(NVARCHAR(20), @ValidOrders)
                + N''; error: '' + CONVERT(NVARCHAR(20), @ErrorOrders)
                + N''; row masuk temp: '' + CONVERT(NVARCHAR(20), @TransferredRows)
                + N''.''
                + CASE
                      WHEN @ErrorOrders > 0
                       AND NULLIF(@ErrorDetail, N'''') IS NOT NULL
                      THEN N'' ErrorDetail: '' + @ErrorDetail
                      ELSE N''''
                  END,
                4000
            );

        IF @InitialTranCount = 0
            COMMIT TRANSACTION;

        IF ISNULL(@ErrorOrders, 0) > 0
           OR ISNULL(@ValidOrders, 0) = 0
           OR ISNULL(@TransferredRows, 0) = 0
            RETURN 16;

        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE
            @ErrorNumber INT = ERROR_NUMBER(),
            @ErrorLine INT = ERROR_LINE(),
            @ErrorMessage NVARCHAR(2048) = ERROR_MESSAGE();

        IF XACT_STATE() = 1
        BEGIN
            IF @InitialTranCount = 0
                ROLLBACK TRANSACTION;
            ELSE
                ROLLBACK TRANSACTION SMK069ReceiveV240;
        END
        ELSE IF XACT_STATE() = -1
        BEGIN
            IF @InitialTranCount > 0
                THROW;

            ROLLBACK TRANSACTION;
        END;

        SET @ErrorMessage = LTRIM(RTRIM(@ErrorMessage));

        SET @Infobar =
            LEFT
            (
                CASE
                    WHEN LEFT(@ErrorMessage, 5) = N''[POS-''
                     AND SUBSTRING(@ErrorMessage, 9, 1) = N'']''
                    THEN @ErrorMessage
                    ELSE
                        N''[POS-999] SMK069 Receive gagal ''
                        + CONVERT(NVARCHAR(20), @ErrorNumber)
                        + N'' line ''
                        + CONVERT(NVARCHAR(20), @ErrorLine)
                        + N'': ''
                        + @ErrorMessage
                END,
                4000
            );

        RETURN 16;
    END CATCH;
END;';
EXEC sys.sp_executesql @Patch35CoreSql;


/* Post-check. */
DECLARE @Patch35Definition NVARCHAR(MAX) =
    COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')), N'');

IF CHARINDEX(N'Peak Season MUST be persisted before #MapView', @Patch35Definition) = 0
    THROW 510353, N'[PATCH-35] Peak Season pre-mapping assignment belum terpasang.', 1;

IF CHARINDEX(N'JSON_VALUE(i.raw_json, ''$.is_peak_season'')', @Patch35Definition) = 0
    THROW 510354, N'[PATCH-35] JSON Peak Season extraction belum terpasang.', 1;

PRINT N'[PATCH-35] SUCCESS - is_peak_season sekarang diset sebelum mapping view snapshot.';
