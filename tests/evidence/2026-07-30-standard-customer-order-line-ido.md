# Evidence — Standard Customer Order Line IDO

## Date

```text
30 July 2026
```

## Tenant Screen

The screenshot was captured from the standard **Customer Order Lines** form in Design Mode.

Observed collection configuration:

```text
Form / area        : Customer Order Lines
Primary Collection : SL.SLCoitems
Collection          : SL.SLCoitems
Collection Name     : blank / not assigned
```

The property tree belongs to the Customer Order line collection and includes line-related metadata.

## Decision

```text
Standard Customer Order header IDO : SL.SLCos
Standard Customer Order line IDO   : SL.SLCoitems
```

Both object names are confirmed directly from the user's SyteLine tenant.

No standard form, IDO, collection, component, or method was modified during discovery.

## Scope Boundary

This evidence confirms object identity only. It does not yet confirm:

```text
- supported standard header methods
- supported standard line methods
- required insert/update property set
- order-number generation behavior
- Customer Order save/post process
```

Those items require separate tenant discovery before custom Process/Reprocess logic is implemented.