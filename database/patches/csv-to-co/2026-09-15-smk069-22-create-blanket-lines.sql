/* =============================================================================
   SMK069 - Patch 22 - Create Blanket Order lines (co_bln_mst)
   -----------------------------------------------------------------------------
   Date    : 2026-09-15
   Object  : dbo.SMK069ProcessCustomerOrderSp
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY

   TENANT EVIDENCE
   ---------------
   Tenant schema and a known-good Blanket Order prove the required mapping:

     co_bln_mst.site_ref          = target site
     co_bln_mst.co_num            = generated SyteLine CO
     co_bln_mst.co_line           = source line
     co_bln_mst.item              = source item
     co_bln_mst.blanket_qty       = source qty_ordered
     co_bln_mst.cont_price        = source unit_price
     co_bln_mst.stat              = 'O'
     co_bln_mst.u_m               = source/item U/M
     co_bln_mst.blanket_qty_conv  = source qty_ordered
     co_bln_mst.cont_price_conv   = source unit_price
     co_bln_mst.ship_site         = target site
     co_bln_mst.allow_on_pick_list= 0
     co_bln_mst.whse              = source warehouse

   Known-good tenant sample R260904056 has blanket_qty/blanket_qty_conv and
   cont_price/cont_price_conv equal to the inbound quantity/price, stat='O',
   ship_site='Default'.

   PURPOSE
   -------
   Patch 21 correctly creates co_mst.type='B' and maps business Cust PO, but
   SMK069ProcessCustomerOrderSp still had no INSERT into dbo.co_bln_mst.
   Therefore the COBL form opened as Blanket but showed blank item and qty 0.

   Patch 22:
   - creates one co_bln_mst row per staging line for every NEW Blanket CO;
   - validates the inserted row count;
   - on an existing matching Blanket CO, repairs missing blanket lines only when
     there are currently ZERO co_bln rows and the existing coitem detail already
     matches staging;
   - refuses partial/mismatched existing blanket detail instead of overwriting it;
   - keeps allow_on_pick_list=0 explicitly;
   - one executable batch, NO GO (Apply Database compatible).

   Existing broken UAT COs are NOT mass-updated automatically. They can be
   repaired safely by invoking SMK069ProcessCustomerOrderSp for their source
   order after this patch; the existing-CO branch performs the missing-line
   repair without creating a duplicate header.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @ProcName   SYSNAME = N'dbo.SMK069ProcessCustomerOrderSp',
    @ProcId     INT,
    @Definition NVARCHAR(MAX),
    @Lf         NCHAR(1) = NCHAR(10),
    @Old        NVARCHAR(MAX),
    @New        NVARCHAR(MAX),
    @Count      INT,
    @BlanketInsert NVARCHAR(MAX);

/* Tenant schema guards. */
IF OBJECT_ID(N'dbo.co_bln_mst', N'U') IS NULL
    THROW 510220, N'[PATCH-22] dbo.co_bln_mst tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.co_bln_mst', N'blanket_qty') IS NULL
 OR COL_LENGTH(N'dbo.co_bln_mst', N'blanket_qty_conv') IS NULL
 OR COL_LENGTH(N'dbo.co_bln_mst', N'cont_price') IS NULL
 OR COL_LENGTH(N'dbo.co_bln_mst', N'cont_price_conv') IS NULL
 OR COL_LENGTH(N'dbo.co_bln_mst', N'stat') IS NULL
 OR COL_LENGTH(N'dbo.co_bln_mst', N'allow_on_pick_list') IS NULL
 OR COL_LENGTH(N'dbo.co_bln_mst', N'whse') IS NULL
    THROW 510221, N'[PATCH-22] Struktur wajib dbo.co_bln_mst tidak sesuai hasil survei tenant.', 1;

SET @ProcId = OBJECT_ID(@ProcName, N'P');
IF @ProcId IS NULL
    THROW 510222, N'[PATCH-22] dbo.SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

SET @Definition = OBJECT_DEFINITION(@ProcId);
IF NULLIF(@Definition, N'') IS NULL
    THROW 510223, N'[PATCH-22] Definition SMK069ProcessCustomerOrderSp tidak dapat dibaca.', 1;

SET @Definition = REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @Definition = REPLACE(@Definition, NCHAR(13), NCHAR(10));

/* Patch 21 / Patch 17 prerequisites. */
IF CHARINDEX(N'@CustPo                  NVARCHAR(100)', @Definition) = 0
 OR CHARINDEX(N'            @CustPo,' + @Lf + N'            N''B'',', @Definition) = 0
    THROW 510224, N'[PATCH-22] Patch 21 belum terpasang. Apply Patch 21 terlebih dahulu.', 1;

IF CHARINDEX(N'            stat,' + @Lf + N'            consolidate', @Definition) = 0
    THROW 510225, N'[PATCH-22] Patch 17 consolidate mapping belum terpasang.', 1;

/* Idempotent exit. */
IF CHARINDEX(N'PATCH-22: create Blanket Order lines', @Definition) > 0
BEGIN
    PRINT N'[PATCH-22] co_bln_mst creation sudah terpasang.';
    RETURN;
END;

/* -------------------------------------------------------------------------
   1. Add counter used by the existing-order repair branch.
   ------------------------------------------------------------------------- */
SET @Old =
      N'        @ExistingLineCount       INT,' + @Lf
    + N'        @ExistingCoNum           CoNumType,';
SET @New =
      N'        @ExistingLineCount       INT,' + @Lf
    + N'        @ExistingBlanketLineCount INT,' + @Lf
    + N'        @ExistingCoNum           CoNumType,';
SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510226, N'[PATCH-22] Anchor deklarasi ExistingLineCount tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* Reusable tenant-confirmed Blanket-line INSERT body. */
SET @BlanketInsert =
      N'            INSERT INTO dbo.co_bln_mst' + @Lf
    + N'            (' + @Lf
    + N'                site_ref,' + @Lf
    + N'                co_num,' + @Lf
    + N'                co_line,' + @Lf
    + N'                item,' + @Lf
    + N'                blanket_qty,' + @Lf
    + N'                cont_price,' + @Lf
    + N'                stat,' + @Lf
    + N'                u_m,' + @Lf
    + N'                blanket_qty_conv,' + @Lf
    + N'                cont_price_conv,' + @Lf
    + N'                ship_site,' + @Lf
    + N'                description,' + @Lf
    + N'                cost_conv,' + @Lf
    + N'                allow_on_pick_list,' + @Lf
    + N'                whse' + @Lf
    + N'            )' + @Lf
    + N'            SELECT' + @Lf
    + N'                @SiteRef,' + @Lf
    + N'                @ExistingCoNum,' + @Lf
    + N'                s.co_line,' + @Lf
    + N'                LTRIM(RTRIM(s.item)),' + @Lf
    + N'                s.qty_ordered,' + @Lf
    + N'                s.unit_price,' + @Lf
    + N'                N''O'',' + @Lf
    + N'                COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''''), i.u_m),' + @Lf
    + N'                s.qty_ordered,' + @Lf
    + N'                s.unit_price,' + @Lf
    + N'                @SiteRef,' + @Lf
    + N'                i.description,' + @Lf
    + N'                ISNULL(i.unit_cost, 0),' + @Lf
    + N'                0,' + @Lf
    + N'                @Whse' + @Lf
    + N'            FROM dbo.ue_SMK069_temp_sales_mst AS s' + @Lf
    + N'            INNER JOIN dbo.item_mst AS i' + @Lf
    + N'              ON i.site_ref = s.SiteRef' + @Lf
    + N'             AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))' + @Lf
    + N'            WHERE s.SiteRef = @SiteRef' + @Lf
    + N'              AND LTRIM(RTRIM(s.co_num)) = @SourceCoNum;';

/* -------------------------------------------------------------------------
   2. Existing matching Blanket CO: verify or repair completely missing co_bln.
      This is deliberately BEFORE staging is marked Processed.
   ------------------------------------------------------------------------- */
SET @Old =
      N'                THROW 50023, @ThrowMessage, 1;' + @Lf
    + N'            END;' + @Lf + @Lf
    + N'            UPDATE dbo.ue_SMK069_temp_sales_mst';

SET @New =
      N'                THROW 50023, @ThrowMessage, 1;' + @Lf
    + N'            END;' + @Lf + @Lf
    + N'            /* PATCH-22: create Blanket Order lines / existing-order repair */' + @Lf
    + N'            SELECT @ExistingBlanketLineCount = COUNT(*)' + @Lf
    + N'            FROM dbo.co_bln_mst' + @Lf
    + N'            WHERE site_ref = @SiteRef' + @Lf
    + N'              AND co_num = @ExistingCoNum;' + @Lf + @Lf
    + N'            IF ISNULL(@ExistingBlanketLineCount, 0) = 0' + @Lf
    + N'            BEGIN' + @Lf
    + @BlanketInsert + @Lf + @Lf
    + N'                IF @@ROWCOUNT <> @LineCount' + @Lf
    + N'                    THROW 50032, N''Jumlah Blanket Order line hasil repair tidak sama dengan staging.'', 1;' + @Lf
    + N'            END' + @Lf
    + N'            ELSE IF @ExistingBlanketLineCount <> @LineCount' + @Lf
    + N'                THROW 50033, N''Existing Blanket Order memiliki jumlah blanket line berbeda dengan staging.'', 1;' + @Lf + @Lf
    + N'            IF EXISTS' + @Lf
    + N'            (' + @Lf
    + N'                SELECT 1' + @Lf
    + N'                FROM dbo.ue_SMK069_temp_sales_mst AS s' + @Lf
    + N'                LEFT JOIN dbo.co_bln_mst AS b' + @Lf
    + N'                  ON b.site_ref = @SiteRef' + @Lf
    + N'                 AND b.co_num = @ExistingCoNum' + @Lf
    + N'                 AND b.co_line = s.co_line' + @Lf
    + N'                WHERE s.SiteRef = @SiteRef' + @Lf
    + N'                  AND LTRIM(RTRIM(s.co_num)) = @SourceCoNum' + @Lf
    + N'                  AND' + @Lf
    + N'                  (' + @Lf
    + N'                      b.co_line IS NULL' + @Lf
    + N'                      OR LTRIM(RTRIM(b.item)) <> LTRIM(RTRIM(s.item))' + @Lf
    + N'                      OR ABS(ISNULL(b.blanket_qty, 0) - ISNULL(s.qty_ordered, 0)) > 0.00000001' + @Lf
    + N'                      OR ABS(ISNULL(b.cont_price, 0) - ISNULL(s.unit_price, 0)) > 0.00000001' + @Lf
    + N'                      OR ISNULL(b.stat, N'''') <> N''O''' + @Lf
    + N'                      OR ISNULL(b.allow_on_pick_list, 1) <> 0' + @Lf
    + N'                  )' + @Lf
    + N'            )' + @Lf
    + N'                THROW 50034, N''Existing Blanket Order detail berbeda dengan staging/target Auto CO.'', 1;' + @Lf + @Lf
    + N'            UPDATE dbo.ue_SMK069_temp_sales_mst';

SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510227, N'[PATCH-22] Anchor existing-order branch tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* -------------------------------------------------------------------------
   3. New Blanket CO: insert co_bln_mst after coitem_mst succeeds.
   ------------------------------------------------------------------------- */
SET @Old =
      N'        IF @@ROWCOUNT <> @LineCount' + @Lf
    + N'            THROW 50028, N''Jumlah Customer Order line yang dibuat tidak sama dengan staging.'', 1;' + @Lf + @Lf
    + N'        /* =============================================================' + @Lf
    + N'           8. Mark staging Processed and commit';

SET @New =
      N'        IF @@ROWCOUNT <> @LineCount' + @Lf
    + N'            THROW 50028, N''Jumlah Customer Order line yang dibuat tidak sama dengan staging.'', 1;' + @Lf + @Lf
    + N'        /* PATCH-22: create Blanket Order lines */' + @Lf
    + N'        INSERT INTO dbo.co_bln_mst' + @Lf
    + N'        (' + @Lf
    + N'            site_ref,' + @Lf
    + N'            co_num,' + @Lf
    + N'            co_line,' + @Lf
    + N'            item,' + @Lf
    + N'            blanket_qty,' + @Lf
    + N'            cont_price,' + @Lf
    + N'            stat,' + @Lf
    + N'            u_m,' + @Lf
    + N'            blanket_qty_conv,' + @Lf
    + N'            cont_price_conv,' + @Lf
    + N'            ship_site,' + @Lf
    + N'            description,' + @Lf
    + N'            cost_conv,' + @Lf
    + N'            allow_on_pick_list,' + @Lf
    + N'            whse' + @Lf
    + N'        )' + @Lf
    + N'        SELECT' + @Lf
    + N'            @SiteRef,' + @Lf
    + N'            @CreatedCoNum,' + @Lf
    + N'            s.co_line,' + @Lf
    + N'            LTRIM(RTRIM(s.item)),' + @Lf
    + N'            s.qty_ordered,' + @Lf
    + N'            s.unit_price,' + @Lf
    + N'            N''O'',' + @Lf
    + N'            COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''''), i.u_m),' + @Lf
    + N'            s.qty_ordered,' + @Lf
    + N'            s.unit_price,' + @Lf
    + N'            @SiteRef,' + @Lf
    + N'            i.description,' + @Lf
    + N'            ISNULL(i.unit_cost, 0),' + @Lf
    + N'            0,' + @Lf
    + N'            @Whse' + @Lf
    + N'        FROM dbo.ue_SMK069_temp_sales_mst AS s' + @Lf
    + N'        INNER JOIN dbo.item_mst AS i' + @Lf
    + N'          ON i.site_ref = s.SiteRef' + @Lf
    + N'         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))' + @Lf
    + N'        WHERE s.SiteRef = @SiteRef' + @Lf
    + N'          AND LTRIM(RTRIM(s.co_num)) = @SourceCoNum;' + @Lf + @Lf
    + N'        IF @@ROWCOUNT <> @LineCount' + @Lf
    + N'            THROW 50035, N''Jumlah Blanket Order line yang dibuat tidak sama dengan staging.'', 1;' + @Lf + @Lf
    + N'        /* =============================================================' + @Lf
    + N'           9. Mark staging Processed and commit';

SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510228, N'[PATCH-22] Anchor new-order coitem completion tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* Normalize header for execution. */
IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
BEGIN
    SET @Definition = REPLACE(@Definition,
        N'CREATE   PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
        N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
    SET @Definition = REPLACE(@Definition,
        N'CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
        N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
    SET @Definition = REPLACE(@Definition,
        N'CREATE PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
        N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
END;

IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
    THROW 510229, N'[PATCH-22] Header procedure tidak dapat dinormalisasi menjadi ALTER PROCEDURE.', 1;

EXEC sys.sp_executesql @Definition;

/* Post-check installed module. */
SET @Definition = OBJECT_DEFINITION(@ProcId);
IF CHARINDEX(N'PATCH-22: create Blanket Order lines', @Definition) = 0
    THROW 510230, N'[PATCH-22] Post-check INSERT co_bln_mst gagal.', 1;
IF CHARINDEX(N'allow_on_pick_list', @Definition) = 0
    THROW 510231, N'[PATCH-22] Post-check allow_on_pick_list gagal.', 1;

PRINT N'[PATCH-22] SUCCESS - Auto CO sekarang membuat co_bln_mst dan dapat repair existing Blanket tanpa blanket lines.';
