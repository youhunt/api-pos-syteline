# Shipment PROD — Mongoose SQL Tables rule

Updated: 2026-09-28

For Shipment custom tables owned by Mongoose (`ue_SMK069_*`), the authoritative
PROD creation/migration path is the **SQL Tables** form / Mongoose metadata path,
not raw `CREATE TABLE` alone.

Why:

- the SQL Tables form adds/maintains application-schema metadata;
- required standard system columns are handled by Mongoose;
- standard table triggers are generated, including the observed
  `Del`, `Insert`, and `UpdatePenultimate` pattern;
- raw physical DDL alone can leave a table that looks structurally correct but
  is incomplete for Mongoose/IDO runtime behavior.

For a table already created by SQL:

1. Open **SQL Tables**.
2. Select the existing table.
3. Use **Update Current Table**.
4. Verify the physical shape is unchanged as expected.
5. Verify the generated standard triggers exist and are enabled.

For a new table:

1. Create it through **SQL Tables**.
2. Define business columns to match the captured UAT schema.
3. Define the RowPointer unique constraint as required by the UAT contract.
4. Verify the standard triggers after creation.
5. Only then build/import dependent IDOs and stored procedures.

Captured SQL files under `deployment/shipment/prod/baseline/` for Mongoose-owned
tables are schema-reference artifacts. They are not the preferred production
creation mechanism.

Current PROD correction:

- `dbo.ue_SMK069_shipment_api_config_mst` was initially created by raw SQL while
  empty. Before proceeding, run **SQL Tables > Update Current Table** and verify
  the three standard triggers.
- `dbo.ue_SMK069_shipment_api_log_mst` must be created through **SQL Tables**
  from the start; do not create it with raw DDL.
