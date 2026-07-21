---
name: amend-tax-return
description: Amending an already-filed individual tax return in consumer tax software (FreeTaxUSA, and transferable to similar web preparers) — reconstructing the as-filed baseline, computing the expected tax delta by hand before touching the software, driving the amendment UI, and verifying the generated 1040-X/8949/Schedule D against that prediction. Use when a taxpayer discovers an omitted or corrected information return (1099-B, 1099-INT, W-2C, K-1), a wrong cost basis, or a missed deduction after filing. Covers employee stock (RSU/ESPP) basis adjustments and wash sales, which is where most amendments go wrong.
metadata: {version: 1.0}
---

# amend-tax-return — amend a filed return without introducing new errors

Framing fact: **an amendment is a diff, and the only way to know the diff is right is to compute it before the software does.** Consumer tax UIs show a single running "amount due" number. That number is the strongest verification signal available — but only if you have a prediction to compare it against. Enter first and the number is unfalsifiable; you will accept whatever appears.

The second framing fact: **most amendments are not about the tax.** They are about document matching. The IRS already holds a copy of the omitted form. Automated matching (CP2000 in the US) assumes a **zero cost basis** on unreported proceeds, so an omitted $30k of stock sales gets proposed as $30k of gain — thousands in tax — even when the true tax effect is a rounding error. Say this out loud early, because a taxpayer who hears "you owe $40 more" will reasonably ask why they're bothering.

## When to use / when NOT to use

Use when:
- An information return was omitted, arrived late, or was corrected after filing.
- Cost basis was wrong — especially employee stock, where it is wrong *by design* (see below).
- Filing status, dependents, or a credit needs to change.

Do NOT use when:
- The return has not been filed or accepted yet — just fix the original.
- The only error is arithmetic the tax agency corrects itself (they recompute and send a notice).
- The change is a pure refund claim outside the statute of limitations (generally 3 years from filing).

Hard stops regardless of instruction (see `references/safety.md`):
- Never type credentials, bank/routing numbers, or government ID numbers. The taxpayer signs in and enters payment details.
- Never click submit/e-file. Stage everything, present the diff, let the taxpayer file.

## The method: predict → enter → discriminate

### Phase 1 — Reconstruct the as-filed baseline

Read the filed return PDF and extract the lines the amendment can touch. Do this before opening the software so you have an independent record; the software's "original" column is a claim you will later check, not a source.

Capture at minimum: total income lines, AGI, deduction, taxable income, tax, each additional tax (surtaxes on investment income or wages), credits, total tax, payments, and refund/balance due.

**Reproduce the filed tax from the filed inputs.** Compute the tax from taxable income and the bracket schedule, honoring preferential rates on qualified dividends and long-term gains. If your number does not match the filed return to the dollar, you have misunderstood something — stop and find it. Matching proves you have the right brackets, the right preferential-rate split, and the right marginal rate for the delta. This single step is what turns the rest of the estimate from a guess into a derivation.

### Phase 2 — Compute the expected delta by hand

From the new documents, compute the change to each affected line, then to AGI, taxable income, and each tax component. Watch for taxes that key off *different* bases than income tax:

- Investment-income surtaxes key off investment income and a MAGI threshold — new interest/dividends/capital gain move them.
- Additional wage-based Medicare-style taxes key off **wage boxes, not taxable income** — a capital-gain change does not move them. Confirm which by recomputing from the filed forms.
- Credits with income phaseouts may or may not move; check the phaseout range against the new AGI rather than assuming.

Write the predicted post-amendment value of every line down before entering anything.

### Phase 3 — Enter, and use the running total as a discriminator

Enter one logical block at a time and check the running amount-due against prediction after each.

The high-value move: **precompute what the tracker would read under each plausible entry error.** These values are usually far apart, which turns one number into a diagnostic. A worked example from a real amendment:

| If this were wrong | Tracker reads |
|---|---|
| Cost-basis adjustment omitted | $516 |
| Short-term wash sale omitted | ~$6 |
| Long-term wash sale omitted | ~$599 **refund** |
| All correct | **$40** |

Landing on the predicted value is then strong evidence about details you cannot see on that screen.

### Phase 4 — Verify against generated forms, not the summary screen

Download the amendment PDF and the as-amended return. Extract text (`pdftotext -layout`) and check:

- **The amendment's "original" column equals the filed return.** If the taxpayer or a prior session nudged an input before the amendment was started, the change column is wrong even when the corrected column is right. This is the single most under-checked field in the whole process.
- Every line you predicted in Phase 2.
- Lines that must **not** move — wages above all, when the change involves employee stock. Wages moving means the compensation income got counted twice.
- Adjustment codes and signs on the capital-gains detail form.

### Phase 5 — Filing posture

- Pay only the **additional tax**. Do not pre-compute interest or penalty into the payment field; tax agencies bill those separately and the amounts are typically cents-to-dollars on a small balance. An overpayment in that field just muddies the return.
- Filing after the original due date generally forces the debit date to today — funds must be present now.
- **E-filed ≠ accepted.** Rejection means nothing was filed and no debit fires. Define done as *accepted*, and follow up.
- Amendment processing is slow (US: commonly 8–12 weeks).

## Employee stock is where amendments go wrong

Brokers are **required** to omit compensation income from the cost basis they report for *covered* stock-plan shares. So the reported basis is understated by design, and reporting it as-is double-taxes income already in the wage box.

Decision rule — do not reason from share type, read the broker's supplemental statement:

| Supplement "adjustment amount" | Action |
|---|---|
| Non-zero | Increase basis by that amount; flag as a basis correction on the detail form |
| Zero | Report basis as-is; **no** adjustment |

Zero appears for two different reasons: shares acquired at $0 (basis already includes the ordinary income), and dispositions with no compensation income at all (e.g. sold below purchase price). Both mean "don't adjust."

Cross-check without trusting the supplement: for a lot whose reported basis equals the employer's stated wage income for that same lot, the income is already included. For a lot where the gap between reported basis and fair market value at acquisition equals the employer's stated income, it is missing and must be added.

Full detail: `references/employee-stock-and-wash-sales.md`.

## Consumer tax software: patterns worth expecting

Verified against FreeTaxUSA, 2025 tax year, 2026-07. Re-check; these UIs change yearly.

**Consolidated-1099 PDF import is not trustworthy.** Observed: it produced two records holding two of three cost-basis subtotals and nothing else — no proceeds, no category letters, no wash-sale amounts, one whole category missing — each marked "needs review" with a "this info is correct" button next to it. Accepting them would have filed large basis against zero proceeds. **Always open every imported record and compare field-by-field against the source, or delete and enter manually.** Treat import as a draft, never as data.

**Entry may be per-category totals, not per-transaction.** Look at the actual form before planning entry: if it asks for a "sales section" (the 8949 box letter) and a section total with no description or date fields, it is a summary-entry model. That changes an 11-row plan into a 3-row plan — and it triggers a **summary statement attachment requirement**, because summary reporting with adjustments obliges you to send the agency the underlying broker statement.

**The attachment usually rides with the e-file**, which removes any separate mail-in transmittal step. Confirm the software says so before promising the taxpayer nothing needs mailing. When several categories come from one broker statement, one attachment typically covers all of them — the UI says so, and only the first slot is marked required.

**Free-text explanation fields silently truncate.** An explanation was cut mid-word at ~832 characters with no warning; the generated form simply ended mid-sentence. **Keep explanations under ~700 characters and always verify the rendered PDF shows the closing sentence.** Prefer prose that degrades gracefully — put the load-bearing summary early, per-line minutiae late.

**Numeric fields round to whole units and will happily accept a typo.** A dropped zero in cents (`1234.5` vs `1234.05`) rounds up by one unit and passes silently. Where a total must tie exactly to a reported figure — gross proceeds above all — re-open the saved record and read the stored digits.

## Prose and formatting for taxpayer-facing text

When handing over text to paste into a form field, **do not hard-wrap it.** Wrapped lines look like broken sentences and the breaks travel with the copy. Emit each paragraph as one continuous line, or write it to a file and point at the file.

## Tooling notes

- `pdftotext -layout` preserves the column structure of tax forms; without `-layout` the columns interleave unreadably.
- **Do not merge PDFs with `pdfunite`** — observed to emit a broken cross-reference table (`reported number of objects ... is not one plus the highest object number`) that PDF readers flag as corrupt. Use `qpdf --empty --pages a.pdf b.pdf -- out.pdf`, then `qpdf --check` the result.
- Always `qpdf --check` any PDF before handing it to someone to upload.

## Binding — what the situation must supply

This skill is jurisdiction- and vendor-neutral in structure. Bind it by establishing:

| Binding | Example (US federal) |
|---|---|
| Amendment form | Form 1040-X, three columns: original / change / correct |
| Capital gains detail | Form 8949 + Schedule D; adjustment codes |
| Bracket schedule + preferential rates | for the specific year and filing status |
| Surtax rules and thresholds | investment-income surtax; wage-based additional Medicare tax |
| Statute of limitations | generally 3 years from filing for refund claims |
| State obligation | many states require a parallel amendment — **check whether the state taxes income at all** before assuming work exists |

## Related skills

- `repo-truth` — same instinct applied to documentation: verify the artifact against reality rather than trusting a summary of it.
