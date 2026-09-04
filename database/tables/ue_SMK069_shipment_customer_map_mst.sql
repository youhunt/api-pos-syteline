IF OBJECT_ID(N'dbo.ue_SMK069_shipment_customer_map_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_shipment_customer_map_mst
    (
        SiteRef          NVARCHAR(8)  NOT NULL,
        SytelineCustNum  NVARCHAR(50) NOT NULL,
        KacsCustCode     NVARCHAR(50) NOT NULL,
        KacsStoreCode    NVARCHAR(50) NOT NULL,
        IsActive         BIT          NOT NULL CONSTRAINT DF_ue_SMK069_ship_cust_map_IsActive DEFAULT (1),
        CreateDate       DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_cust_map_CreateDate DEFAULT (GETDATE()),
        RecordDate       DATETIME     NOT NULL CONSTRAINT DF_ue_SMK069_ship_cust_map_RecordDate DEFAULT (GETDATE()),
        RowPointer       UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_ue_SMK069_ship_cust_map_RowPointer DEFAULT (NEWID()),

        CONSTRAINT PK_ue_SMK069_shipment_customer_map_mst
            PRIMARY KEY (RowPointer),

        CONSTRAINT UQ_ue_SMK069_shipment_customer_map_mst
            UNIQUE (SiteRef, SytelineCustNum),

        CONSTRAINT CK_ue_SMK069_ship_cust_map_CustCode
            CHECK (LEN(LTRIM(RTRIM(KacsCustCode))) > 0),

        CONSTRAINT CK_ue_SMK069_ship_cust_map_StoreCode
            CHECK (LEN(LTRIM(RTRIM(KacsStoreCode))) > 0)
    );
END;
