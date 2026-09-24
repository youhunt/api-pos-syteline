# 49 — Shipment PROD Migration Package

Date: 2026-09-24

The production migration package is maintained under:

```text
deployment/shipment/prod/
├── README.md
├── apply-database/
└── query-select/
```

The deployment runbook is the execution authority for PROD. The historical files under `database/patches/shipment/` remain implementation history/source and must not be treated as a blind PROD run list.

Key production protections:

```text
- no UAT endpoint hardcoded into PROD config
- config template fails if api-uat is detected
- master/business scheduler remain OFF after configuration
- initial Shipments / Run = 1
- retry policy = 1 minute, max 1440
- no UAT retry/API-log/ActiveBGTasks data migration
- one controlled RUN ONCE before recurring START
- emergency-stop SQL included
```

A clean PROD tenant additionally requires exact current UAT baseline exports for objects whose current tenant definitions are not yet authoritative standalone sources in Git. See:

```text
database/shipment/SMK069_SHIPMENT_SOURCE_INVENTORY.md
deployment/shipment/prod/README.md
```

PROD GO remains blocked until target evidence exists for the current duplicate `data is exist` classification and Patch 22 PRICE guard, plus confirmed PROD URLs and approved credential handling.
