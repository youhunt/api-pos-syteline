# PROD config table Mongoose trigger verification — FAIL

Date: 2026-09-28
Environment: PROD
Object: dbo.ue_SMK069_shipment_api_config_mst

Query returned no rows for user triggers:

```text
TriggerName | is_instead_of_trigger | is_disabled
<no rows>
```

Interpretation:

- physical config table exists and its column/index baseline previously passed;
- however the expected standard Mongoose table triggers are not present;
- this table was originally created by raw SQL in PROD;
- do not proceed with dependent scheduler/IDO work until the table is registered/updated through SQL Tables and the standard triggers are generated.

Expected trigger pattern after repair:

```text
ue_SMK069_shipment_api_config_mstDel
ue_SMK069_shipment_api_config_mstInsert
ue_SMK069_shipment_api_config_mstUpdatePenultimate
```

All must be enabled. The Insert trigger is expected to be INSTEAD OF, matching the Mongoose pattern observed on the API log table.
