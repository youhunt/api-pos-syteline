# SMK069 — List of Customer Orders and cust_po Revision

> **SUPERSEDED — 27 August 2026**
>
> This document described an intermediate design where POS still supplied `conum` separately from `cust_po`. That design is no longer current.
>
> Use the current master document instead:
>
> ```text
> docs/22-smk069-pos-contract-v2-20260827.md
> ```

## Current V2 semantics

```text
POS sends cust_po
POS does NOT send conum
POS does NOT send unit_price

Receive generates co_num = R + YYMM + 5-digit running number
Receive resolves unit_price from itemcustprice_mst

co_mst.co_num      = generated temp.co_num
co_mst.cust_po     = temp.cust_po
coitem_mst.co_num  = generated temp.co_num
co_bln_mst.co_num  = generated temp.co_num
```

Confirmed UAT:

```text
cust_po = POS08270002
co_num  = R260822003
```

The historical content of this file should not be used as an implementation contract.
