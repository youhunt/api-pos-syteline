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
   SMK069 - POS UOM Mapping, Patch 05
   -----------------------------------------------------------------------------
   Object   : dbo.ue_SMK069_pos_uom_map_mst                  (NEW TABLE)
   Date     : 2026-09-07
   Design   : docs/28-shipment-infor-endpoint-and-uom.md
   Used by  : Patch 06 (SMK069BuildShipmentJsonSp)

   WHY
   ---
   The POS Shipment API expects UOM as an INTEGER code of its own
   ("UOM": 3), while SyteLine carries an alphabetic unit of measure on
   coitem.u_m ("TRY", "CTN", "KG"). SMK069_ShipmentAPI_mst passes u_m through
   unchanged, so the payload has always carried the SyteLine value.

   There is no existing table anywhere in SMK069 that translates the two. This
   is it.

   DELIBERATELY EMPTY
   ------------------
   No rows are seeded. The only number seen so far is 3 for TRY, and that came
   from a hand-edited UAT payload, not from the POS team. Sending an invented
   UOM code to a live POS system is worse than sending none: the shipment would
   be accepted against the wrong unit and the error would surface downstream in
   stock, not here.

   Patch 06 therefore refuses to build a payload for any u_m that is not mapped,
   and names the offending value.

   TO FILL IT
   ----------
   1. List the SyteLine units actually in use on shipments (query below).
   2. Send that list to the POS team and ask for their integer code for each.
   3. INSERT the confirmed pairs. Nothing else is required.

   MONGOOSE METADATA
   -----------------
   This creates the physical table directly. If the table should also be
   maintainable through a Mongoose form or IDO, create it through Object Builder
   metadata as SMK_SMK069_pos_uom_map instead and let the environment add the
   ue_ prefix, then skip this patch. The column list below matches what Mongoose
   would generate, so either route ends at the same shape.
   ============================================================================= */

IF OBJECT_ID('dbo.ue_SMK069_pos_uom_map_mst', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_pos_uom_map_mst
    (
        /* ----- business columns ----------------------------------------- */
        SiteRef         NVARCHAR(8)     NOT NULL,
        syteline_um     NVARCHAR(20)    NOT NULL,   -- coitem.u_m, e.g. TRY, CTN, KG
        pos_uom_code    INT             NOT NULL,   -- integer code expected by POS
        description     NVARCHAR(100)   NULL,
        is_active       TINYINT         NOT NULL
            CONSTRAINT DF_SMK069_uom_map_is_active DEFAULT (1),

        /* ----- Mongoose standard columns -------------------------------- */
        RowPointer      UNIQUEIDENTIFIER NOT NULL ROWGUIDCOL
            CONSTRAINT DF_SMK069_uom_map_RowPointer DEFAULT (NEWID()),
        CreatedBy       NVARCHAR(128)   NOT NULL
            CONSTRAINT DF_SMK069_uom_map_CreatedBy DEFAULT (SUSER_SNAME()),
        UpdatedBy       NVARCHAR(128)   NOT NULL
            CONSTRAINT DF_SMK069_uom_map_UpdatedBy DEFAULT (SUSER_SNAME()),
        CreateDate      DATETIME        NOT NULL
            CONSTRAINT DF_SMK069_uom_map_CreateDate DEFAULT (GETDATE()),
        RecordDate      DATETIME        NOT NULL
            CONSTRAINT DF_SMK069_uom_map_RecordDate DEFAULT (GETDATE()),
        NoteExistsFlag  TINYINT         NOT NULL
            CONSTRAINT DF_SMK069_uom_map_NoteExists DEFAULT (0),
        InWorkflow      TINYINT         NOT NULL
            CONSTRAINT DF_SMK069_uom_map_InWorkflow DEFAULT (0),

        CONSTRAINT PK_ue_SMK069_pos_uom_map_mst
            PRIMARY KEY CLUSTERED (SiteRef, syteline_um),
        CONSTRAINT UQ_ue_SMK069_pos_uom_map_RowPointer
            UNIQUE (RowPointer)
    );
END;
GO

/* -----------------------------------------------------------------------------
   STEP 1 - which SyteLine units actually appear on pending shipments?
   Run this in Query Execution and send the result to the POS team.
   -------------------------------------------------------------------------- */
/*
SELECT
    v.UOM              AS syteline_um,
    COUNT(*)           AS lines,
    COUNT(DISTINCT v.DN_No) AS shipments,
    MIN(v.product_code) AS contoh_item
FROM dbo.SMK069_ShipmentAPI_mst AS v
WHERE v.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ISNULL(v.shipment_qty, 0) > 0
GROUP BY v.UOM
ORDER BY COUNT(*) DESC;
*/

/* -----------------------------------------------------------------------------
   STEP 2 - insert the pairs the POS team confirms. Template only; the value
   below is NOT confirmed and is commented out on purpose.
   -------------------------------------------------------------------------- */
/*
INSERT INTO dbo.ue_SMK069_pos_uom_map_mst (SiteRef, syteline_um, pos_uom_code, description)
VALUES
    (RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0)), N'TRY', 3, N'belum dikonfirmasi POS');
*/

/* -----------------------------------------------------------------------------
   STEP 3 - what is still unmapped, and therefore still blocks a payload.
   -------------------------------------------------------------------------- */
/*
SELECT DISTINCT v.UOM AS belum_dipetakan
FROM dbo.SMK069_ShipmentAPI_mst AS v
WHERE v.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ISNULL(v.shipment_qty, 0) > 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.ue_SMK069_pos_uom_map_mst AS m
      WHERE m.SiteRef = v.site_ref
        AND m.is_active = 1
        AND UPPER(LTRIM(RTRIM(m.syteline_um))) COLLATE DATABASE_DEFAULT
            = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), v.UOM)))) COLLATE DATABASE_DEFAULT
  );
*/
