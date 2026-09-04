IF OBJECT_ID(N'dbo.ue_SMK069_shipment_uom_map_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_shipment_uom_map_mst
    (
        SiteRef       NVARCHAR(8)  NOT NULL,
        SytelineUom   NVARCHAR(50) NOT NULL,
        KacsUom       INT          NOT NULL,
        IsActive      BIT          NOT NULL CONSTRAINT DF_ue_SMK069_ship_uom_map_IsActive DEFAULT (1),
        CreateDate    DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_uom_map_CreateDate DEFAULT (GETDATE()),
        RecordDate    DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_uom_map_RecordDate DEFAULT (GETDATE()),
        RowPointer    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_ue_SMK069_ship_uom_map_RowPointer DEFAULT (NEWID()),

        CONSTRAINT PK_ue_SMK069_shipment_uom_map_mst
            PRIMARY KEY (RowPointer),

        CONSTRAINT UQ_ue_SMK069_shipment_uom_map_mst
            UNIQUE (SiteRef, SytelineUom),

        CONSTRAINT CK_ue_SMK069_ship_uom_map_KacsUom
            CHECK (KacsUom > 0)
    );
END;
