# Evidence — Customer Extension Assembly Is Binary Only

Date: 30 July 2026

## Tenant Form

Standard form: `IDO Extension Class Assemblies`

Filter/result:

```text
Assembly Name = Customer
```

## Confirmed Values

```text
Assembly Name         : Customer
Revision Num          : 1
Revision Date         : 5/12/2026
Locked By             : blank
Access As             : BaseSyteLine
Assembly Type         : Binary Only
Extend And Replace    : blank
Language              : blank
Assembly File Version : blank
References            : blank
Filename              : Customer
Full Name             : Customer, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null
Symbol File Name      : Customer.pdb
```

## Technical Conclusion

The tenant publishes the standard `Customer` extension assembly as **Binary Only**.

This confirms that the previously identified runtime owner:

```text
Customer.SLCos
Assembly: Customer
Method: CreateCoAndLines
```

is backed by a binary assembly record rather than a build-from-source assembly record in this tenant.

The form screenshot does not expose extension source code or the exact `CoAndLineInfoJson` schema. The listed symbol file name does not itself provide the JSON contract in the visible tenant metadata.

## Safety Result

```text
No assembly checkout
No edit
No import
No build
No save
No CreateCoAndLines invocation
No Customer Order created or modified
```
