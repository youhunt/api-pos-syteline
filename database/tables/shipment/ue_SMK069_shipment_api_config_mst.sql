/* REFERENCE ONLY — DO NOT USE AS THE AUTHORITATIVE PROD CREATION PATH.
   This is a captured physical-schema reference.
   Create/update this Mongoose-owned custom table through the SQL Tables form
   so application-schema metadata and standard Del/Insert/UpdatePenultimate
   triggers are generated. If the physical table already exists from raw SQL,
   use SQL Tables > Update Current Table, then verify the generated triggers.
*/

/* =============================================================================
   SMK069 Shipment PROD baseline
   Object : dbo.ue_SMK069_shipment_api_config_mst
   Source : current UAT sys.columns/sys.types/default/index evidence 2026-09-28

   Notes
   -----
   * Creates schema only. NO UAT config row / endpoint / credential is copied.
   * RowPointer is NOT ROWGUIDCOL in UAT.
   * UAT has one UNIQUE constraint/index on RowPointer and no database PK.
   * nvarchar lengths below convert sys.columns.max_length bytes -> characters.
   * Apply Database: ONE executable batch, NO GO.
   ============================================================================= */

CREATE TABLE dbo.ue_SMK069_shipment_api_config_mst
(
    CreatedBy           UsernameType     NOT NULL
        CONSTRAINT DF_SMK069_shipapi_cb DEFAULT (SUSER_SNAME()),
    UpdatedBy           UsernameType     NOT NULL
        CONSTRAINT DF_SMK069_shipapi_ub DEFAULT (SUSER_SNAME()),
    CreateDate          CurrentDateType  NOT NULL
        CONSTRAINT DF_SMK069_shipapi_cd DEFAULT (GETDATE()),
    RecordDate          CurrentDateType  NOT NULL
        CONSTRAINT DF_SMK069_shipapi_rd DEFAULT (GETDATE()),
    RowPointer          RowPointerType   NOT NULL
        CONSTRAINT DF_SMK069_shipapi_rp DEFAULT (NEWID()),
    NoteExistsFlag      FlagNyType       NOT NULL
        CONSTRAINT DF_SMK069_shipapi_nef DEFAULT ((0)),
    InWorkflow          FlagNyType       NOT NULL
        CONSTRAINT DF_SMK069_shipapi_iw DEFAULT ((0)),
    SiteRef             SiteType         NOT NULL
        CONSTRAINT DF_SMK069_shipapi_site DEFAULT (RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))),
    ApiName             NVARCHAR(100)    NOT NULL
        CONSTRAINT DF_SMK069_shipapi_name DEFAULT (N'SHIPMENT'),
    EndpointUrl         NVARCHAR(1000)   NOT NULL,
    HttpMethod          NVARCHAR(10)     NOT NULL
        CONSTRAINT DF_SMK069_shipapi_method DEFAULT (N'POST'),
    ContentType         NVARCHAR(100)    NOT NULL
        CONSTRAINT DF_SMK069_shipapi_content DEFAULT (N'application/json'),
    AuthType            NVARCHAR(20)     NOT NULL
        CONSTRAINT DF_SMK069_shipapi_authtype DEFAULT (N'NONE'),
    AuthHeader          NVARCHAR(100)    NULL,
    AuthValue           NVARCHAR(2000)   NULL,
    TimeoutSeconds      INT              NOT NULL
        CONSTRAINT DF_SMK069_shipapi_timeout DEFAULT ((-60)),
    IsActive            TINYINT          NOT NULL
        CONSTRAINT DF_SMK069_shipapi_active DEFAULT ((-1)),
    LoginUrl            NVARCHAR(1000)   NULL,
    SuccessMode         NVARCHAR(20)     NULL,
    SchedulerEnabled    TINYINT          NULL,
    MaxBatchSize        INT              NULL,
    MaxAttempts         INT              NULL,
    BackoffBaseMinutes  INT              NULL,
    BackoffCapMinutes   INT              NULL,

    CONSTRAINT IX_ue_SMK069_shipment_api_config_mst_RowPointer
        UNIQUE NONCLUSTERED (RowPointer)
)
