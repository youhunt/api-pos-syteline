# SMK069 Site Isolation Standard

**Status:** Mandatory architecture rule
**Effective:** 19 October 2026

## Rule

Every SMK069 object that reads, writes, validates, displays, queues, retries,
archives, processes, or reports site-owned transactional data MUST be isolated
by the active Mongoose SiteRef.

Do not treat SiteRef as an optional per-feature patch.

## Runtime standard

For SQL stored procedures that operate on site-owned data:

~~~sql
DECLARE @Site SiteType;
SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
EXEC SetSiteSp @Site, NULL;
~~~

Every access to a site-owned _mst/custom transactional table must constrain the
same site, for example:

~~~sql
WHERE SiteRef = @Site
~~~

Joins to standard Mongoose tables must also include the appropriate site key,
for example `site_ref = @Site` or `site_ref = source.SiteRef`.

## UI / IDO standard

Every form collection that exposes site-owned data must be site-isolated.

Acceptable mechanisms:

~~~text
- site-aware generated Mongoose view/IDO, when the property contract remains valid
- permanent/collection SiteRef filter bound to the active session site
- site-aware SQL view where required by a read-only projection
~~~

A shared form must never hardcode a site literal such as DEFAULT or TRN_TBB.

## Views

Every custom view over site-owned data must either:

~~~text
1. expose SiteRef and require the caller to filter it, or
2. filter internally using the active Mongoose site context.
~~~

A view that unions current/history data must apply site isolation to every branch.

## IDO methods

Method registration metadata and entity collection source are separate concerns.
Changing an IDO base source must not silently remove properties required by form
event bindings or method parameters such as SiteRef.

## History / archive / retry

History, archive, retry, idempotency, and duplicate checks must include SiteRef
in their logical scope. Cross-site rows must never affect another site's retry,
duplicate detection, attempt number, or operator history.

## Keys / uniqueness

Any logical key that can legitimately repeat across sites must include SiteRef.
Review unique constraints and indexes accordingly before enabling multiple sites.

## Review scope

Audit all of the following for every SMK069 module:

~~~text
[ ] physical custom tables
[ ] unique constraints / indexes
[ ] SQL views
[ ] stored procedures
[ ] triggers
[ ] IDO entity collections
[ ] IDO methods
[ ] primary/secondary form collections
[ ] form method parameters
[ ] background tasks / schedulers
[ ] history/archive/retry logic
[ ] verification and UAT queries
~~~

## Exception

Objects that are intentionally global/shared may omit SiteRef only when that
global behavior is explicitly documented. The default assumption for SMK069
transactional/runtime data is SITE-OWNED.