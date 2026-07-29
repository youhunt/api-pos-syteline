/*
    Object  : dbo.ue_SMK069ValidateCustomerSp
    Purpose : Validate cust_num for one SMK069 staged Customer Order group.
    Scope   : Custom staging validation only. This procedure does not create
              or update standard Customer Order records.

    IDO publication target:
        IDO         : ue_SMK069TempSales
        Method Name : ValidateCustomer
        Method Type : Stored Procedure - Standard Method
*/

CREATE OR ALTER PROCEDURE dbo.ue_SMK069ValidateCustomerSp
    @SiteRef dbo.SiteType,
    @CoNum   dbo.CoNumType,
    @Infobar dbo.InfobarType OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @InvalidCustNum dbo.CustNumType;

    SET @SiteRef = LTRIM(RTRIM(@SiteRef));
    SET @CoNum   = LTRIM(RTRIM(@CoNum));
    SET @Infobar = NULL;

    IF NULLIF(@SiteRef, N'') IS NULL
    BEGIN
        SET @Infobar = N'SiteRef wajib diisi.';
        RETURN 16;
    END;

    IF NULLIF(@CoNum, N'') IS NULL
    BEGIN
        SET @Infobar = N'CO Number wajib diisi.';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        WHERE s.SiteRef = @SiteRef
          AND s.co_num = @CoNum
    )
    BEGIN
        SET @Infobar = N'Data staging tidak ditemukan untuk SiteRef '
                     + RTRIM(@SiteRef)
                     + N' dan CO Number '
                     + RTRIM(@CoNum)
                     + N'.';
        RETURN 16;
    END;

    /*
        Find the first blank or unknown customer in the selected staged CO.
        customer_mst cust_seq = 0 represents the customer master header.
    */
    SELECT TOP (1)
        @InvalidCustNum = NULLIF(LTRIM(RTRIM(s.cust_num)), N'')
    FROM dbo.ue_SMK069_temp_sales_mst AS s
    WHERE s.SiteRef = @SiteRef
      AND s.co_num = @CoNum
      AND
      (
          NULLIF(LTRIM(RTRIM(s.cust_num)), N'') IS NULL
          OR NOT EXISTS
          (
              SELECT 1
              FROM dbo.customer_mst AS c
              WHERE c.site_ref = @SiteRef
                AND c.cust_num = s.cust_num
                AND c.cust_seq = 0
          )
      )
    ORDER BY s.co_line;

    IF @@ROWCOUNT > 0
    BEGIN
        SET @Infobar =
            CASE
                WHEN @InvalidCustNum IS NULL
                    THEN N'Customer wajib diisi dan harus terdaftar di customer_mst.'
                ELSE N'Customer ' + RTRIM(@InvalidCustNum)
                   + N' tidak ditemukan di customer_mst.'
            END;

        UPDATE dbo.ue_SMK069_temp_sales_mst
        SET process_status = N'E',
            validation_msg = @Infobar
        WHERE SiteRef = @SiteRef
          AND co_num = @CoNum;

        /* Business validation completed successfully; the business result is Error. */
        RETURN 0;
    END;

    UPDATE dbo.ue_SMK069_temp_sales_mst
    SET process_status = N'V',
        validation_msg = NULL
    WHERE SiteRef = @SiteRef
      AND co_num = @CoNum;

    RETURN 0;
END;
GO
