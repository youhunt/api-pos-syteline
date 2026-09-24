# Shipment PROD — UAT Export / Import Checklist

Prepared: 2026-09-24

Use this checklist when PROD is a clean or partially populated tenant.

## Rule

Export the **exact current UAT tenant definition/artifact** for items marked EXPORT. Do not recreate them from stale historical source files.

| Layer | Object / artifact | Action for PROD | Notes |
|---|---|---|---|
| SQL View | dbo.SMK069_ShipmentAPI_mst | EXPORT exact UAT / compare PROD | Current prefixed DN contract is tenant-critical |
| SQL Table | dbo.ue_SMK069_shipment_api_config_mst | EXPORT DDL / migrate schema only | Do not copy UAT row values or credentials |
| SQL Table | dbo.ue_SMK069_shipment_api_log_mst | EXPORT DDL / migrate schema only | Do not copy UAT history |
| SQL Proc | dbo.SMK069BuildShipmentJsonSp | EXPORT exact UAT if baseline missing | Repo standalone historical body is stale |
| SQL Proc | dbo.SMK069PrepareShipmentSendSp | EXPORT exact UAT if baseline missing | Current full body not authoritative in repo |
| SQL Proc | dbo.SMK069CompleteShipmentSendSp | use current baseline + migration rule | Patch 15 DN behavior required |
| SQL Table | dbo.ue_SMK069_shipment_retry_mst | CREATE via PROD pack | Empty in PROD |
| SQL Table | dbo.ue_SMK069_shipment_schedule_mst | CREATE via PROD pack | Seed safe OFF |
| SQL Views | Scheduler dashboard / queue views | CREATE via PROD pack | Read models |
| IDO | ue_SMK069ShipmentTransport | EXPORT exact UAT definition | Register all current SP/extension methods |
| IDO | ue_SMK069ShipmentApiConfigs | EXPORT/import | No credential field on form |
| IDO | ue_SMK069ShipmentSchedules | EXPORT/import | Current properties/methods |
| IDO | ue_SMK069ShipmentRetries | EXPORT/import | Read-only operational grid |
| IDO | ue_SMK069ShipmentApiLogs | EXPORT/import current UAT | Read-only troubleshooting |
| IDO | ue_SMK069ShipmentSchedulerDashboard | EXPORT/import | Read-only dashboard |
| IDO | ue_SMK069ShipmentSchedulerQueue | EXPORT/import | Read-only queue |
| Built-in IDO | ActiveBGTasks | DO NOT EXPORT/CREATE | Use PROD built-in runtime IDO |
| Custom Assembly | current Shipment extension | EXPORT exact UAT / import / compile | Must include scheduler + duplicate-success rule |
| Form | ue_SMK069ShipmentScheduler REV8 | EXPORT/import sanitized artifact | Replace PROD credential placeholders locally only |
| Task Definition | SMK069ShipmentScheduler | EXPORT/import definition | Do not copy active recurrence instance |
| Active Task | ActiveBGTasks runtime row | DO NOT MIGRATE | PROD START creates a new TaskNumber |

## Data that must stay in UAT

Do not move:

- retry state/history rows;
- API log rows;
- schedule LastRun/runtime state;
- ActiveBGTasks instances;
- UAT EndpointUrl/LoginUrl;
- UAT username/password/token/AuthValue;
- controlled UAT DN retry state.

## Required evidence captured before cutover

Store screenshots/exports of:

- current UAT form version;
- IDO methods/properties;
- custom assembly compile/source revision;
- task definition executable name;
- current UAT config with credentials redacted;
- current Shipment View DN expression;
- Patch 21 retry settings;
- Patch 22 marker/guard verification;
- one successful Shipment lifecycle and one duplicate-idempotent lifecycle if available.
