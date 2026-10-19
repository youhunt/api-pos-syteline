# SMK069 Form Site Isolation Pattern

**Verified reference:** 19 October 2026  
**Source of truth for active site:** `CONTEXT_INFO()`

## Verified working form pattern

The tenant-verified CSV Console uses:

~~~text
StdFormPredisplay seq 0
  SP!.ue_SMK069GetCurrentSiteSp(RVAR V(CurrentSite))

StdFormPredisplay seq 1
  ActiveSite = CurrentSite

Primary collection
  SiteRef = FV(ActiveSite)

Secondary site-owned collections
  existing parent/link filter
  + SiteRef = ActiveSite
~~~

This keeps form visibility aligned with the same active-site source already used
by SMK069 SQL runtime procedures.

## Impact rule

Adding `ue_SMK069GetCurrentSiteSp` has no write-side effect by itself. It only
returns the current site. A form is affected only when it explicitly calls the
helper or adds an ActiveSite filter.

Do not replace existing business SP parameters or IDO methods unless the form
contract specifically requires the active site.

## Current form audit

| Form | Data source | Site action |
|---|---|---|
| ue_SMK069PosCsvBatchConsole | custom CSV batch/detail IDOs | VERIFIED pattern; keep |
| ue_SMK069APISalesErrorProcessing | custom temp sales + history | APPLY same helper to primary temp collection; History SQL view already site-filtered |
| ue_SMK069ShipmentScheduler | custom schedule/dashboard/queue/log/retry IDOs | REVIEW/APPLY SiteRef filtering to site-owned collections; do not blindly filter ActiveBGTasks |
| ue_SMK069ShipmentAPITest | no site-owned collection in form | no form filter required; verify called SPs remain CONTEXT_INFO-aware |
| ue_SMK069_BlanketReleases | standard SL IDOs | do not add custom ActiveSite filter by default |
| ue_SMK069_CustomerContracts | standard SL IDO | do not add custom ActiveSite filter by default |

## CSV Console verified details

The verified export:
~~~text
forms/csv-to-co/exports/ue_SMK069PosCsvBatchConsole-ActiveSite-CONTEXT_INFO-2026-10-19.xml
~~~

contains:
- primary SiteRef filter;
- secondary CSV-detail SiteRef filter;
- StdFormPredisplay current-site lookup;
- existing CSV business method calls unchanged.

## Important schema follow-up

Form isolation does not change physical key definitions. In the current CSV
schema the batch primary key is still `batch_id`, and CSV detail uniqueness is
`batch_id + row_no`. Because multiple sites share a physical database, review
whether SiteRef should become part of logical/physical uniqueness before any
site is allowed to reuse the same BatchId.

Do not change those keys as part of the form patch without a separate migration,
FK review, duplicate-data precheck, and UAT.
