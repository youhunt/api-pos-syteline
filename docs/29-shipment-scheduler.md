# 29 — Shipment Scheduler

> **Date:** 8 September 2026
> **Requirement:** `docs/24-smk069-current-handoff-2026-09-03.md` §2 — Shipment data must be sent to the POS API automatically every hour by default, with an adjustable interval, and the mechanism must not depend on a user opening a form.
> **Patches:** `2026-09-08-smk069-07-shipment-scheduler-tables.sql`, `2026-09-08-smk069-08-shipment-scheduler-procs.sql`
> **Status:** SQL written; extension method and TaskMan definition pending — see §5 and §6

* * *

## 1. Where the work is split

```text
TaskMan task (hourly, adjustable)
      |
      v
ue_SMK069ShipmentTransport.SMK069SendPendingShipments      <- extension class, §5
      |
      +-- SMK069GetShipmentConfigSp        endpoint, timeout, batch size
      +-- SMK069GetPendingShipmentsSp      which DNs are due
      +-- login once
      |
      +-- per DN:
      |     SMK069PrepareShipmentSendSp    build payload, open log row
      |     HTTP POST                      the only thing SQL cannot do
      |     SMK069CompleteShipmentSendSp   S/E, sets api_post on success
      |     SMK069RecordShipmentAttemptSp  attempt count, backoff, give up
      |
      v
   summary
```

Everything about **which** shipments go, **when** a failed one is tried again,
and **when to give up** lives in SQL. The extension class only performs the HTTP
call and the loop. That keeps the policy changeable by an operator without a
code deployment, which is what §2 of the handoff asks for.

* * *

## 2. Why a new retry table

`ue_SMK069_shipment_api_log_mst.RetryCount` cannot drive a backoff. Prepare
creates a **new log row** whenever the previous one is already in error, so the
counter never grows past 1 for a repeatedly failing shipment. Counting attempts
needs a key that survives across log rows, and that key is `SiteRef + ShipmentId`
— the same idempotency key the rest of the Shipment design already uses.

`ue_SMK069_shipment_retry_mst` holds exactly that: attempt count, next attempt
time, state, and the last error.

| State | Meaning |
| --- | --- |
| `P` | pending, still inside the attempt budget |
| `X` | exhausted, will not be picked up again until an operator resets it |
| `S` | succeeded, kept for history |

* * *

## 3. Retry and backoff

Defaults from `ue_SMK069_shipment_config_mst`:

```text
max_attempts         5
backoff_base_minutes 15
backoff_cap_minutes  480
```

Delay is `base × 2^(attempt−1)`, capped:

| Attempt | Next try after |
| --- | --- |
| 1 | 15 minutes |
| 2 | 30 minutes |
| 3 | 60 minutes |
| 4 | 120 minutes |
| 5 | gives up — state `X` |

A shipment that fails five times stops being sent. It stays visible in the
operator query in patch 08, and returns to the queue only when someone resets
`retry_state` to `P` after fixing the cause.

Without this, one malformed DN would hit the POS API 24 times a day forever.

* * *

## 4. Credentials

**The KACS username and password are TaskMan task parameters, not table
columns.** `ue_SMK069_shipment_config_mst` deliberately has no credential
column, so no `SELECT` on that table can reveal them.

Two things follow, and both matter:

The extension method takes `Username` and `Password` as input parameters, and
**Mongoose echoes every input parameter back in the IDO response**. If anyone
invokes this method by hand from Postman or a form, the password comes back in
the response body and lands in that client's history. It is safe when TaskMan is
the only caller, because nothing renders that response. Do not invoke it
interactively with production credentials.

Rotating the password means editing the task definition, not a table row. That
is more friction than a config column, and it is the trade that was chosen.

* * *

## 5. The extension method

`SMK069SendPendingShipments` must live in the **same class** as the existing
methods, because Mongoose binds one extension class per IDO. It is an edit to
`extension-classes/SMK069ShipmentSenderExtension.cs`, not a new file.

A complete revision 3 of that class is now in the repository as
`extension-classes/SMK069ShipmentSenderExtension.rev3.cs`, carrying three
changes:

1. **`DN_No` is a string everywhere.** Since 7 September the view emits
   `P96325` and the SQL chain moved to `NVARCHAR`; a `long` parameter cannot
   carry that, which is what produced
   `IDOValueType.GetValue: failed to parse normalized string [P96325], Type = Int64`.
2. **The shipment path constant points at `infor_dn`.** Only
   `SMK069SendOneShipmentKacs` uses it — the batch sender reads `endpoint_url`
   from configuration, so the still-disputed base path (docs/28 §6) can be
   corrected without a rebuild.
3. **`SMK069SendPendingShipments` added**, with three private helpers that read
   config, read the pending list, and record each attempt.

> **Diff before replacing.** The file was derived from the class as it stood on
> 4 September. Anything edited in the tenant after that — including a DN_No
> change already made by hand — is not in it. Compare, then take what is
> missing; do not paste over work that cannot be seen from here. The `.rev3.cs`
> suffix keeps the current source intact until the diff is done.

Two consequences worth stating before the rebuild:

**The type change is not free.** `SMK069SendOneShipment` and
`SMK069SendOneShipmentKacs` both change their first parameter from `Int64` to
`String`. Positions do not move, so the IDO method metadata needs a type edit
on parameter 1 of each, plus the same on the Prepare stored-procedure method.
Miss one and the failure looks exactly like the Preview JSON error.

**A login failure deliberately records nothing.** If the batch cannot log in,
it returns 16 without touching any retry row. A wrong password must not burn
the attempt budget of every pending shipment — otherwise one bad credential
change would exhaust the whole queue in five hours and leave every DN in state
`X`.

After rebuilding `ue_SMK069ShipmentExtensions`, register the method on
`ue_SMK069ShipmentTransport`:

```text
Method Name   : SMK069SendPendingShipments
Method Type   : Extension Class - Standard Method
Transactional : NOT checked
```

| Seq | Name | Direction | Type |
| ---: | --- | --- | --- |
| 1 | Username | Input | String |
| 2 | Password | Input | String |
| 3 | MaxShipments | Input | Int32 |
| 4 | Candidates | Output | Int32 |
| 5 | Succeeded | Output | Int32 |
| 6 | Failed | Output | Int32 |
| 7 | Exhausted | Output | Int32 |
| 8 | FailedList | Output | String |
| 9 | Infobar | Output | String |

The three new stored procedures must also be registered on the same IDO as
Stored Procedure methods, with their parameters in the order patch 08 declares
them — the extension class invokes them by position, so a reordered parameter
fails silently rather than loudly.

## 6. TaskMan — verify before building

**`DN_No` is a string now.** Everything registered before 7 September declared
it as `Int64`. Confirm the whole chain is `String`, or the batch will fail on
the first `P96325` exactly as Preview JSON did:

```sql
SELECT p.name AS sp, pr.name AS param, pr.parameter_id AS urutan,
       TYPE_NAME(pr.user_type_id) AS tipe, pr.max_length
FROM sys.procedures AS p
JOIN sys.parameters AS pr ON pr.object_id = p.object_id
WHERE p.name LIKE 'SMK069%Shipment%'
ORDER BY p.name, pr.parameter_id;

SELECT c.name AS kolom, t.name AS tipe, c.max_length
FROM sys.columns AS c
JOIN sys.types  AS t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.ue_SMK069_shipment_api_log_mst');
```

`ShipmentId` on the log table must hold `P96325`. If it is an integer, Prepare
cannot store the DN and `SiteRef + ShipmentId` stops working as an idempotency
key — fix that before scheduling anything.

**Then check what TaskMan can actually call in this tenant.** Background tasks
are commonly defined against a stored procedure; invoking an IDO method directly
is version-dependent and has not been verified here. If TaskMan can only run a
stored procedure, the HTTP call cannot happen inside it, and the scheduler needs
a different host — a Mongoose Event/Action calling the IDO method, or an
external caller hitting the REST endpoint on a schedule.

**Do not settle this by assumption.** Open Background Task definitions and look
at what task types the tenant offers before building the task.

Interval: hourly by default, set on the task's schedule. It is never written
into a stored procedure — `docs/24` §2 forbids that, and the config table is
about policy, not cadence.

* * *

## 7. Order of work

```text
[ ] apply patch 07, then 08
[ ] confirm endpoint_url in the config row against the POS team (docs/28 §6)
[ ] verify the DN_No type chain is String end to end
[ ] verify ue_SMK069_shipment_api_log_mst.ShipmentId holds P96325
[ ] add SMK069SendPendingShipments to the extension class, rebuild
[ ] register the three SP methods and the extension method on the IDO
[ ] invoke SMK069SendPendingShipments by hand with is_enabled = 0
    -> expect "dinonaktifkan", nothing sent
[ ] set is_enabled = 1, invoke by hand with MaxShipments = 1
[ ] confirm the retry row, the outbound log row, and Api_post
[ ] force a failure (bad endpoint) and confirm next_attempt_date moves out
[ ] confirm a shipment gives up after max_attempts
[ ] only then create the TaskMan task
```

The last line matters. A scheduler that starts before the failure path is proven
turns one bad shipment into a stream of failed requests against a partner's
production API.
