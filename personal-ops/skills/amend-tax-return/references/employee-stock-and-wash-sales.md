# Employee stock basis and wash sales

Depth for `amend-tax-return`. Load when the amendment involves RSUs, ESPP, options, or any
sale where a wash sale may apply. US federal framing; the mechanics generalize.

## Why employee-stock basis is wrong on purpose

When stock-plan shares vest or are purchased at a discount, the compensation element is
ordinary income and lands in the wage box of the year's wage statement. It is taxed there.

Regulations then **prohibit** the broker from including that compensation element in the cost
basis it reports to the tax agency for *covered* securities. The broker reports only what the
holder paid. So the reported basis is understated by exactly the compensation amount, and
reporting it unadjusted taxes the same dollars twice — once as wages, once as capital gain.

The fix is a basis adjustment on the capital-gains detail form, **not** a change to wages.
Wages are already correct. This is the single most important sentence in this file: an
amendment that moves the wage line has double-counted.

## Covered vs noncovered

| | Basis reported to agency? | Compensation in reported basis? | Adjustment needed? |
|---|---|---|---|
| Covered stock-plan shares | Yes | **No** (prohibited) | **Yes** |
| Noncovered shares acquired at $0 | No | Yes (broker free to include) | No |

Noncovered basis is self-reported, so the broker includes the full economic basis. Nothing to fix.

## The decision rule

Read the broker's **stock plan transactions supplement** (naming varies: "supplemental
information", "cost basis supplement"). It carries an *adjustment amount* column per lot.

- Non-zero → add it to basis. That is the compensation income.
- Zero → report basis as-is.

Do not infer from share type or covered status alone. A **covered** lot can legitimately show
zero — e.g. a qualifying disposition sold below purchase price generates no ordinary income.
Sitting next to covered lots that do need adjustment, it is an easy and expensive mistake.

## Independent cross-checks

Verify the supplement rather than trusting it:

**Shares acquired at $0 (typical RSU).** Reported basis should equal quantity × fair market
value at vest, which should equal the employer's stated wage income for that lot. If reported
basis == employer's stated income, the income is already in basis. No adjustment.

**Discounted purchase (typical ESPP).** Reported basis equals what was paid. True basis is
fair market value at purchase. The gap should equal the employer's stated income for that lot.
That gap is the adjustment.

Employers usually issue two statements — one for vesting-type awards, one for purchase-type —
and their totals should reconcile to the wage-box supplemental codes. Reconciling them is the
strongest available confirmation that the wage line is right and only basis needs fixing.

## Wash sales

A wash sale disallows a loss when substantially identical stock is acquired within 30 days
before or after the sale. The disallowed loss is **not forfeited** — it is added to the basis
of the replacement shares and recovered when those are sold.

**A vest or plan purchase is an acquisition.** This is routinely missed. Someone on a quarterly
vest schedule who sells at a loss within 30 days of a vest has a wash sale, regardless of intent
and regardless of whether they "bought" anything. Recurring vest schedules make this common
rather than exotic.

Consequences worth stating to the taxpayer:

- A loss you expected to deduct may be entirely disallowed this year.
- This can flip the sign of the amendment — a disallowed loss can turn an expected refund into
  a balance due.
- The deferred basis is a **future-year asset**. Record the amount and which lots carry it.
  It is silently lost if the taxpayer changes brokers or forgets, since the recovery happens
  years later at sale.

Follow the broker's reported wash-sale figures. Deviating creates exactly the agency mismatch
the amendment exists to prevent. For noncovered lots the broker does not report the disallowance
to the agency, but its number is still the right one to use.

## Detail-form mechanics (US Form 8949)

Adjustments go in the adjustment column with a code, and **sign matters**:

| Situation | Code | Sign | Effect |
|---|---|---|---|
| Reported basis too low (employee stock) | `B` | **negative** | reduces gain |
| Wash sale loss disallowed | `W` | **positive** | increases gain |
| Row is a summary of many transactions | `M` | — | pairs with attached statement |

Codes combine and are written in alphabetical order: `BM`, `MW`. A summary row with a basis
correction reads `BM`; a summary row with a wash sale reads `MW`.

Sanity check each row: `proceeds − basis + adjustment = gain`. Then check the category subtotals
carry to the right summary-schedule lines, and that short-term and long-term stay separated.

## What to hand the taxpayer afterwards

- The deferred wash-sale basis: total amount and which holdings carry it.
- That the amendment did **not** change wages, and why that is the correct outcome.
- That the broker's supplement should be retained — it is the evidence for the basis adjustment
  if the agency ever asks.
