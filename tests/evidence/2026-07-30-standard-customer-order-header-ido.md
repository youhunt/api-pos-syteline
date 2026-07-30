# Evidence — Standard Customer Order Header IDO

## Date

```text
30 July 2026
```

## Tenant Screen

The standard **Customer Orders** form was opened in Design Mode and its primary collection was inspected.

Observed configuration:

```text
Primary Collection : SL.SLCos
Collection          : SL.SLCos
Collection Name     : blank / not assigned
```

The visible primary-collection properties included Customer Order-related fields such as:

```text
ItemId
ItemWarnings
AckStat
AdrName
Amount
ApplyToInvNum
```

## Verification Result

```text
Standard Customer Order header IDO : SL.SLCos — CONFIRMED
Standard Customer Order line IDO   : NOT YET CONFIRMED
```

`SL.SLCos` is the tenant-confirmed standard header IDO for the Customer Orders form.

No standard form, collection, IDO, or method was modified during this discovery step.

## Next Discovery Step

Identify the secondary collection used for Customer Order lines by locating the collection whose properties include line-level fields such as:

```text
CoNum
CoLine
Item
QtyOrdered
UM
Price
DueDate
Whse
```

Do not assume the line IDO name until it is visible in the tenant.