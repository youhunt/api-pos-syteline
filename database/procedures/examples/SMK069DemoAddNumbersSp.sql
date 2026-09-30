/* Demo SP dengan OUTPUT parameter.
   Apply Database: satu batch, tanpa GO.
*/
CREATE OR ALTER PROCEDURE dbo.SMK069DemoAddNumbersSp
    @A       INT,
    @B       INT,
    @Total   INT OUTPUT,
    @Infobar NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Total = ISNULL(@A, 0) + ISNULL(@B, 0);

    SET @Infobar = CONCAT(
        N'SMK069DemoAddNumbersSp berhasil. ',
        CONVERT(NVARCHAR(20), ISNULL(@A, 0)),
        N' + ',
        CONVERT(NVARCHAR(20), ISNULL(@B, 0)),
        N' = ',
        CONVERT(NVARCHAR(20), @Total)
    );

    RETURN 0;
END;
