# IDO-004 — Item Maps Smoke Test

## Result

```text
IDO             : ue_SMKRSCPosItemMaps
Status          : PASS
Creation Method : IDO Wizard
Environment     : SyteLine / Mongoose 10 Web Client
```

The user confirmed that the item-mapping IDO was created successfully.

## Expected Primary Key

```text
1. SourceSystem
2. TargetSite
3. PosItemCode
```

## Expected Minimum Result

```text
IDO discovery      : PASS
Property discovery : PASS
Load Collection    : PASS
Empty collection   : EXPECTED until mapping records are entered
```

## Notes

- The tenant applies the `ue_` custom-object prefix.
- IDO Runtime metadata may require `Discard IDO Cache` and a new web-client session before the IDO is visible.
- No source data or mapping records were required for the metadata smoke test.
