# 28 — Shipment: the endpoint was wrong, and UOM must be an integer

> **Date:** 7 September 2026
> **Source:** POS/KACS team (Pak Pantja), WhatsApp thread 7 Sep 15:13–15:47
> **Supersedes:** `docs/24-smk069-current-handoff-2026-09-03.md` §17 and §19 for the endpoint and the WHS_CODE question
> **Patches:** `2026-09-07-smk069-05-create-pos-uom-map.sql`, `2026-09-07-smk069-06-shipment-uom-integer.sql`
> **Status:** patches written; blocked on two answers from the POS team — see §6

---

## 1. Three findings

**The endpoint was wrong the entire time.** `kacs_dn` is the KACS direction.
Infor → POS uses `infor_dn`. Every `1009 Invalid params` recorded between
3 and 7 September was a request to the wrong route.

**`UOM` must be an integer.** `"UOM": "3"` is rejected; `"UOM": 3` is expected.
A numeric string is still a string.

**`1010 data is exist` means the payload passed validation.** This is the
finding that closes the investigation. A malformed payload answers `1009`.
Because the 7 Sep UAT attempt against `infor_dn` answered `1010`, everything
except the DN number was accepted.

---

## 2. What that proves about the payload

The payload that reached `1010` carried:

```json
{
  "CUST_CODE": "PHD0001",
  "WHS_CODE": "P963",
  "DOC_NO": "R260902058",
  "STORE_CODE": "DEV4",
  "DETAIL": [{ "SHIPMENT_QTY": 390.00000000, "PRICE": 855000.00000000, ... }]
}
```

Every one of those is a SyteLine-side value, and all of them were accepted.
Trailing eight-decimal numbers were accepted too.

**The theory that `CUST_CODE`, `WHS_CODE` and `STORE_CODE` had to be translated
into POS-side codes was wrong.** It came from reading `S060` / `R950` / `R919`
in the KACS sample and inferring a code space that does not in fact apply to
`infor_dn`. `SMK069_ShipmentAPI_mst` is correct on those columns; nothing needs
to be built there.

The open items in `docs/24` §17 (`WHS_CODE` not finalized) and §18
(`STORE_CODE` needs source confirmation) can be closed on the evidence of the
`1010` response, unless the POS team says otherwise.

---

## 3. UOM is the one real payload defect

`SMK069_ShipmentAPI_mst` exposes `coi.u_m AS UOM` — the SyteLine alphabetic
unit, `TRY`, `CTN`, `KG`. POS wants its own integer code.

No table anywhere in SMK069 translates the two. Patch 05 creates one:

```text
dbo.ue_SMK069_pos_uom_map_mst
    SiteRef + syteline_um  ->  pos_uom_code (INT)
```

**It is seeded empty on purpose.** The only number seen so far is `3` for `TRY`,
and that came from a hand-edited UAT payload, not from the POS team. An invented
UOM code is worse than none: POS would accept the shipment against the wrong
unit and the error would surface downstream in stock rather than at the API.

Patch 06 therefore refuses to build a payload when any line's `u_m` is unmapped,
and names the offending values in the Infobar. Nothing ships until the mapping
is real.

To get the list POS needs to answer:

```sql
SELECT
    v.UOM                   AS syteline_um,
    COUNT(*)                AS lines,
    COUNT(DISTINCT v.DN_No) AS shipments,
    MIN(v.product_code)     AS contoh_item
FROM dbo.SMK069_ShipmentAPI_mst AS v
WHERE v.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ISNULL(v.shipment_qty, 0) > 0
GROUP BY v.UOM
ORDER BY COUNT(*) DESC;
```

Send that to the POS team and ask for their integer code per row.

---

## 4. What must NOT change

`SHIPMENT_QTY` and `PRICE` keep `CONVERT(DECIMAL(19,8), ...)`. The accepted
payload carried `390.00000000` and `855000.00000000`. There is no evidence they
need to be integers, and changing them on a hunch is how the last four days were
spent.

`CUST_CODE`, `WHS_CODE`, `STORE_CODE`, `DOC_NO` stay as the view produces them.

`THROW`/return behaviour of the Shipment procedures is untouched by these
patches.

---

## 5. Endpoint change in the extension class

`extension-classes/SMK069ShipmentSenderExtension.cs` hard-codes the wrong path:

```csharp
private const string KacsShipmentPath = "/inventory-phi/v1/kacs_dn";
```

This is **not** shipped as a rewritten file. The class is ~1200 lines of working
production code and the correct base path is still disputed (§6), so replacing
it wholesale to change one string is the wrong trade. Edit the constant block in
place once §6 is answered.

For UAT there is no need to touch the class at all. The generic method
`SMK069SendOneShipment` already takes `EndpointUrl` as a parameter — pass the
full Infor URL explicitly and the constants never come into play. Only the
`SMK069SendOneShipmentKacs` convenience wrapper depends on them.

---

## 6. Blocked on two answers

**The base path is ambiguous.** The POS team gave two different forms in the
same conversation:

```text
https://api-uat.pizzahut.co.id/inventory/v1/infor_dn        (URL as sent)
https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn    ("just swap kacs_dn for infor_dn")
```

One of them produced the `1010`, so one of them is right. This value gets baked
into a constant; confirm it before it is.

**How unique must `DN_NO` be?** `25` was rejected as already used. That value is
SyteLine's `shipment_id` — a small integer that restarts at 1 per site. The KACS
sample used `DN98112`. If POS requires `DN_NO` to be unique across all senders,
sending a raw `shipment_id` will collide constantly, and multi-site makes it
worse. A prefix such as `SL<site><shipment_id>` may be required.

This is a data-model question, not a bug, and it is cheaper to settle now than
after the hourly scheduler is live.

---

## 7. Next UAT

One request, not a probe sweep:

```text
endpoint : the confirmed infor_dn URL
payload  : DN25's payload, UOM as an integer
DN_NO    : a value not yet used
```

`201` with `code 200` closes the transport investigation and the work moves to
the pending-batch sender and the hourly scheduler in `docs/24` §20.

The probe scripts under `tests/tools/` — `Test-KacsShipmentPayload.ps1`,
`Test-KacsShapeProbe.ps1`, `Test-KacsReverseBisect.ps1` — were all built to
search for a payload defect that turned out to be an endpoint defect. They are
kept as evidence of what was ruled out; none of them should be run again.
