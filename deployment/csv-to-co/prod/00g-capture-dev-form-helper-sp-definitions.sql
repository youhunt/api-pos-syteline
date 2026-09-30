/* =============================================================================
   SMK069 DEV SOURCE CAPTURE — FORM/IDO HELPER STORED PROCEDURES
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-30
   Tool  : Query Select on the VERIFIED DEV environment
   Rule  : EXACTLY ONE SELECT statement.

   Why:
   The imported DEV forms/IDOs call helper stored procedures that were not yet
   present in the consolidated PROD runtime package. Capture the exact DEV
   definitions before adding them to PROD; do not reconstruct them from memory.
   ============================================================================= */

SELECT
    p.name AS procedure_name,
    p.modify_date,
    CONVERT(VARCHAR(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(VARBINARY(MAX), m.definition)
        ),
        2
    ) AS definition_sha256,
    n.chunk_no,
    SUBSTRING
    (
        m.definition,
        ((n.chunk_no - 1) * 3500) + 1,
        3500
    ) AS definition_chunk
FROM sys.procedures AS p
INNER JOIN sys.sql_modules AS m
    ON m.object_id = p.object_id
CROSS APPLY
(
    SELECT TOP
    (
        CASE
            WHEN LEN(m.definition) = 0 THEN 1
            ELSE CONVERT(INT, CEILING(LEN(m.definition) / 3500.0))
        END
    )
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS chunk_no
    FROM sys.all_objects
) AS n
WHERE p.schema_id = SCHEMA_ID(N'dbo')
  AND p.name IN
  (
      N'SMK069InitializeCsvTestBatchSp',
      N'SMK069ConfirmCsvUploadSp',
      N'SMK069ValidateFilteredStagingSp'
  )
ORDER BY p.name, n.chunk_no;