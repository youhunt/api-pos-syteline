# SMK069 PROD Form Import Audit — 28 Sep 2026

Scope: CSV / POS inbound -> Blanket Customer Order only.

Source reviewed: imported FormsAndObjects export supplied on 28 Sep 2026.

## Imported forms confirmed

```text
ue_SMK069APISalesErrorProcessing
  Caption: SMK API SALES ERROR PROCESSING

ue_SMK069PosCsvBatchConsole
  Caption: SMK POS CSV TO BLANKET CO
```

## Error Processing — required corrections

The imported Process/Reprocess event still calls:

```text
SMK069ProcessCustomerOrderSp(
  SiteRef,
  co_num,
  CustSeq = 0,
  ...
)
```

Final contract must call it with the business key and mapped customer sequence:

```text
SMK069ProcessCustomerOrderSp(
  SiteRef,
  CustPo,
  CustSeq,
  ...
)
```

Exact event response target:

```text
ue_SMK069TempSales.SMK069ProcessCustomerOrderSp(
  PARMS(
    VAR P(SiteRef),
    VAR P(CustPo),
    VAR P(CustSeq),
    VAR,
    RVAR V(CreatedCoNum),
    RVAR V(Success),
    MESSAGE
  )
  ERRORMESSAGE(mBackEndMessage)
  SUCCESSMESSAGE(mBackEndMessage)
)
```

Reason:
- final business linkage is `cust_po`;
- `@SourceCoNum` is only a compatibility parameter name;
- final processor validates the mapped `cust_seq`, so hardcoding zero can reject
  a valid mapped customer sequence.

The following display-only columns should be read-only on the form:

```text
SyteLine CO Number -> object.CreatedCoNum
CustSeq            -> object.CustSeq
Name               -> object.Name
Is Peak Season     -> object.IsPeakSeason
```

## CSV console — verified event chain

The imported one-hit chain is the safe FIX2 design:

```text
Sequence 0 -> ACTION(Import) COMPONENT(btnCsvToCoOneHit)
Sequence 1 -> disable object
Sequence 2 -> SMK069ParseCsv
Sequence 3 -> SMK069RunCsvFullProcess
Sequence 4 -> refresh object
Sequence 5 -> refresh object2
```

Do not replace it with the withdrawn nested Upload-event pattern.

One correction remains:

```text
object2.IsPeakSeason
  Checkbox
  Read Only = True
```

## PROD acceptance gate

Before business UAT:

```text
[ ] Error Processing Process/Reprocess passes CustPo
[ ] Error Processing Process/Reprocess passes mapped CustSeq
[ ] Error Processing display-only columns are read-only
[ ] CSV Peak checkbox is read-only
[x] CSV one-hit direct Import -> Parse -> Full Process chain is correct
```
