# SMK069ShipmentScheduler — ActiveBGTasks runtime evidence

Date: 2026-09-10

Tenant check used **IDO Runtime / Load Collection** against the standard Mongoose IDO:

```text
IDO        : ActiveBGTasks
Properties : TaskNumber, TaskName, TaskStatusCode
Filter     : TaskName = 'SMK069ShipmentScheduler'
```

Observed result:

```text
0 actual rows
```

The blank `*` row shown by the Load Collection form is the UI insert/placeholder row, not a returned ActiveBGTasks task.

Interpretation:

- the custom Shipment schedule row may still show `IsEnabled=1`;
- this does **not** prove TaskMan is registered;
- at the time of this check there was no actual active/waiting/running `SMK069ShipmentScheduler` in `ActiveBGTasks`;
- the one-form scheduler must therefore read `ActiveBGTasks` directly and surface `NOT REGISTERED` instead of trusting only custom DB flags.

This evidence also confirms the Cloud-safe runtime source is the Mongoose IDO `ActiveBGTasks`, not `dbo.ActiveBGTasks` from the application database.
