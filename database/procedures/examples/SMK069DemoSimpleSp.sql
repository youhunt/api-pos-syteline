/* Demo SP untuk belajar Extension Class -> Stored Procedure.
   Apply Database: satu batch, tanpa GO.
*/
CREATE OR ALTER PROCEDURE dbo.SMK069DemoSimpleSp
AS
BEGIN
    SET NOCOUNT ON;

    /* Sengaja tidak melakukan perubahan data.
       Hanya untuk membuktikan Extension Class bisa memanggil SP. */

    RETURN 0;
END;
