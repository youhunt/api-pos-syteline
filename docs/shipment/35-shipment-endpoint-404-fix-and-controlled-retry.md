# 35 — Shipment endpoint 404 fix + controlled retry gate

> Date: 9 September 2026  
> Scope: **Shipment Outbound SyteLine → POS API only**  
> Patch: `database/patches/shipment/2026-09-09-smk069-16-fix-shipment-endpoint-and-hold-scheduler.sql`

## 1. Status before Patch 16

Tenant verification already completed:

```text
Patch 14 Rev.2
DN_No_Type        nvarchar
DocNoNonBlocking  PASS
EmptyStringJson   PASS

Patch 15
Patch15Marker               PASS
OldBigintAssignmentRemoved  PASS
StringDnPresent             PASS
```

Therefore:

```text
P96331 missing DOC_NO local hard stop  FIXED
Complete nvarchar -> bigint            FIXED
HTTP 404 page not found                REMAINING PRE-RETRY BLOCKER
```

## 2. Active tenant config evidence

Query Select returned:

```text
SiteRef          Default
ApiName          SHIPMENT
IsActive         1
SchedulerEnabled 1
LoginUrl         https://api-uat.pizzahut.co.id/service-auth/login-once
EndpointUrl      https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
HttpMethod       POST
ContentType      application/json
SuccessMode      KACS_V1
```

P96330 and P96332 using this active config returned:

```text
HTTP 404
Response=404 page not found
```

This is route-level evidence, independent from the previously fixed Complete conversion.

## 3. Why Patch 16 selects `/inventory-phi/v1/infor_dn`

The 7 Sep POS/KACS handoff preserved in `docs/shipment/28-shipment-infor-endpoint-and-uom.md` records two candidate Infor → POS routes:

```text
https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
```

It also records that one `infor_dn` UAT attempt reached POS business validation and returned:

```text
1010 data is exist
```

The active `/inventory/v1/infor_dn` candidate is now directly proven to return HTTP 404. With the same UAT host and the two-candidate evidence set, Patch 16 moves configuration to the remaining documented candidate:

```text
https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
```

This is an evidence-based elimination, not a random probe sweep.

## 4. Scheduler safety hold

Patch 16 also sets:

```text
SchedulerEnabled = 0
```

Reason: current queue attempts are limited:

```text
P96330 3/5
P96331 3/5
P96332 2/5
```

Changing EndpointUrl must not immediately allow the background scheduler to consume the next attempts before a one-DN controlled UAT is reviewed.

Patch 16 does **not**:

- reset retries;
- alter retry counters;
- change NextAttemptDate;
- send HTTP;
- change credentials;
- change LoginUrl;
- change HttpMethod/ContentType/SuccessMode;
- change Shipment View / Build / Prepare / Complete.

## 5. Apply Patch 16

Run through Infor Apply Database:

```text
database/patches/shipment/2026-09-09-smk069-16-fix-shipment-endpoint-and-hold-scheduler.sql
```

Expected:

```text
OK - Patch 16 applied.
EndpointUrl = https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
SchedulerEnabled = 0 (SAFETY HOLD).
Patch ini TIDAK melakukan HTTP call dan TIDAK Reset Retry.
Verifikasi config lalu lakukan controlled one-DN UAT sebelum scheduler diaktifkan kembali.
```

## 6. Query Select verification

Tenant Query Select rules still apply: pure SELECT, no trailing semicolon.

```sql
SELECT
    SiteRef,
    ApiName,
    IsActive,
    SchedulerEnabled,
    LoginUrl,
    EndpointUrl,
    HttpMethod,
    ContentType,
    SuccessMode
FROM dbo.ue_SMK069_shipment_api_config_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ApiName = N'SHIPMENT'
```

Expected critical values:

```text
IsActive         1
SchedulerEnabled 0
EndpointUrl      https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
HttpMethod       POST
ContentType      application/json
SuccessMode      KACS_V1
```

## 7. Controlled retry after config verification

Do not re-enable the scheduler yet.

Use:

```text
Max/Run = 1
Reset ONE DN only
manual/controlled Run Now
```

Recommended first candidate: **P96331**.

Why:

- its missing DOC_NO local blocker is fixed by Patch 14 Rev.2;
- it has not yet spent an attempt against the corrected endpoint;
- `DOC_NO=""` may still be accepted or rejected by POS; either result gives real API-contract evidence;
- Complete is now fixed by Patch 15, so error finalization should no longer throw nvarchar→bigint.

Expected decision tree:

```text
HTTP 404 again
  -> endpoint assumption still wrong; STOP, do not try another DN

HTTP reaches business response (e.g. 4xx/201 with POS JSON code)
  -> route is fixed; inspect POS response contract

Business success
  -> verify Complete/API log/retry state/Api_post, then consider re-enabling scheduler
```

Do not reset P96330/P96332 until the first corrected-endpoint UAT has been reviewed.
