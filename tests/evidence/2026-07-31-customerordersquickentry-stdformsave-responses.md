# Evidence — CustomerOrdersQuickEntry StdFormSave Responses

Date: 31 July 2026

## Tenant Form

```text
CustomerOrdersQuickEntry
```

## Observation

In Design Mode, the `StdFormSave` event was expanded. Five enabled responses were visible:

| Sequence | Response | Disabled | Visible Response Parameters |
| ---: | --- | --- | --- |
| 0 | `Generate event` | `false` | `LineSetValueForPricingEngine( COLID(object.SLCoitems) )` |
| 1 | `Run Script` | `false` | `BdcDeleteVar(COLINE) COLID(object.SLCoitems)` |
| 2 | `Method Call` | `false` | `MGCore.DefineVariables.DefineVariableSp( PARMS(VAR C...` — truncated in the UI |
| 3 | `Form Script Method` | `false` | `SMK_Save()` |
| 4 | `Form Script Method` | `false` | `SMK025_UpdateReqDateLineIfEmpty()` |

## Confirmed Interpretation

`StdFormSave` contains custom form logic in addition to standard framework behavior. In particular, sequence 3 calls:

```text
SMK_Save()
```

This is now the strongest tenant-confirmed source candidate for discovering whether the form:

```text
- constructs the CreateCoAndLines payload;
- invokes SL.SLCos.CreateCoAndLines;
- or performs another custom save sequence before normal parent/child persistence.
```

No claim is made yet about the contents of `SMK_Save()` because its source has not been opened.

The other visible responses indicate pre-save line/pricing and variable handling. Sequence 2 is recorded as truncated and must not be reconstructed by guessing.

## Next Controlled Step

Open the form script source for:

```text
SMK_Save()
```

and capture the complete method body. Do not edit, compile, save, or execute the form.

## Safety Result

```text
No Customer Order save
No CreateCoAndLines invocation
No form modification
No metadata save
No direct SQL insert
```
