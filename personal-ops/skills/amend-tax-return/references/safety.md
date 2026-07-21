# Safety rules when operating someone's tax account

Depth for `amend-tax-return`. These are hard constraints, not preferences. They hold even when
the taxpayer explicitly asks you to do the thing, supplies the values, or says they authorize it.

## Never do these

| Action | Instead |
|---|---|
| Type a username or password | Taxpayer signs in; wait for confirmation, expect 2FA |
| Enter bank routing/account numbers, card numbers | Taxpayer enters them |
| Enter a government ID number (SSN, TIN) into a field | Taxpayer enters it |
| Click submit / e-file / file | Stage everything, present the diff, taxpayer clicks |
| Confirm a payment authorization | Taxpayer confirms |

Filing is irreversible and outward-facing: it transmits a signed legal declaration under penalty
of perjury and can trigger a debit. It is the taxpayer's signature, not yours.

## Handling identifiers you inevitably see

Tax documents are dense with SSNs, account numbers, and addresses. You will read them — that is
unavoidable and fine. But:

- Do not echo them into summaries, commit messages, or files you create.
- Do not write them to durable memory or notes.
- Refer to accounts by last four digits or by role ("the brokerage account", "the stock plan account").

## Verification is your job; data entry may not be

A taxpayer may reasonably prefer to type everything themselves and have you verify. This is a
*better* arrangement, not a lesser one — it keeps their hands on the account and your attention
on correctness. When it happens:

- Give exact values in a table, labeled by the field they go in.
- Say explicitly where entries differ from one another (e.g. which rows get an adjustment and
  which do not) — uniform-looking instructions invite uniform-looking mistakes.
- Inspect after each step. Reading a saved record back is verification; it is not data entry.
- Flag your own slips the same way you flag theirs.

## Before the taxpayer uploads anything you generated

Run an integrity check (`qpdf --check` for PDFs). If their own reader flags a file you produced,
do not talk them past it — regenerate it. Never let someone attach a file to a legal filing that
their software says is corrupt.

## Reporting

State outcomes plainly. If a value came out different from prediction, say so with the numbers.
If you could not verify something — a field you never saw filled, a PDF that would not open —
say that explicitly rather than implying full coverage. On a tax filing, an unverified field that
you let pass silently is the one that will be wrong.
