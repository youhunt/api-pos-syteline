/*
    Tenant-confirmed fix for dbo.GetSiteContext().

    dbo.GetSiteContext() reads:
        RTRIM(CAST(CONTEXT_INFO() AS NVARCHAR(8)))

    Therefore CONTEXT_INFO must be populated from NVARCHAR(8), not VARCHAR(8).
*/

/* Controlled diagnostic */
DECLARE
    @PreviousContextInfo VARBINARY(128) = CONTEXT_INFO(),
    @SiteContextInfo     VARBINARY(128),
    @EmptyContextInfo    VARBINARY(128) = 0x,
    @SiteRef             NVARCHAR(8) = N'DEFAULT';

SET @SiteContextInfo = CONVERT
(
    VARBINARY(128),
    CONVERT(NVARCHAR(8), LTRIM(RTRIM(@SiteRef)))
);

SET CONTEXT_INFO @SiteContextInfo;

SELECT
    dbo.GetSiteContext() AS GetSiteContext,
    CONTEXT_INFO() AS ContextInfoBinary,
    CONVERT(NVARCHAR(8), CONTEXT_INFO()) AS ContextInfoText;

IF @PreviousContextInfo IS NULL
    SET CONTEXT_INFO @EmptyContextInfo;
ELSE
    SET CONTEXT_INFO @PreviousContextInfo;

/*
    Apply the same pattern inside dbo.SMK069ProcessCustomerOrderSp:

    1. Add variables:

        @PreviousContextInfo VARBINARY(128),
        @SiteContextInfo     VARBINARY(128),
        @EmptyContextInfo    VARBINARY(128) = 0x,

    2. Before BEGIN TRY:

        SET @PreviousContextInfo = CONTEXT_INFO();
        SET @SiteContextInfo = CONVERT
        (
            VARBINARY(128),
            CONVERT(NVARCHAR(8), LTRIM(RTRIM(@SiteRef)))
        );

    3. Immediately before INSERT dbo.co_mst:

        SET CONTEXT_INFO @SiteContextInfo;

        IF LTRIM(RTRIM(dbo.GetSiteContext())) <> LTRIM(RTRIM(@SiteRef))
            THROW 50029, N'GetSiteContext tidak sama dengan SiteRef setelah context diaktifkan.', 1;

    4. Restore the previous context after all standard header/line triggers finish,
       before COMMIT, and again after ROLLBACK in CATCH:

        IF @PreviousContextInfo IS NULL
            SET CONTEXT_INFO @EmptyContextInfo;
        ELSE
            SET CONTEXT_INFO @PreviousContextInfo;

    Do not use this incorrect conversion:

        CONVERT(VARBINARY(128), CONVERT(VARCHAR(8), @SiteRef))
*/
