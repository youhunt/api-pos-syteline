# SMK069 Cloud Multi-Line Customer Order Success

Date: 2026-08-03
Environment: Infor Cloud tenant

## Source Order

```text
SiteRef      : DEFAULT
SourceCoNum  : TEST000003
Customer     : C000001
Warehouse    : MAIN
Terms        : CBD
Tax Code     : PPN11%
```

## Staging Input

```text
Line 1 : Item AA00001, Qty 1 KG, Unit Price 10000
Line 2 : Item AA00001, Qty 2 KG, Unit Price 15000
Expected net total : 40000
```

## Processing Result

```text
CreatedCoNum : CO26080002
Success      : 1
ReturnValue  : 0
Infobar      : Customer Order CO26080002 berhasil dibuat dari source order TEST000003.
```

## Standard Line Verification

IDO: `SLCoitems`

```text
CO26080002 / Line 1 / AA00001 / Qty 1 / KG / Price 10000 / MAIN
CO26080002 / Line 2 / AA00001 / Qty 2 / KG / Price 15000 / MAIN
```

Exactly two lines were returned. This confirms the Cloud direct-processing path creates a single Customer Order with multiple lines and preserves line numbers, quantities, U/M, prices, and warehouse values.
