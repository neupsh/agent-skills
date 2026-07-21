# personal-ops

Skills for high-stakes personal administration — the kind of task where a mistake is expensive,
slow to discover, and hard to reverse, and where the agent's job is to be *verifiably* right rather
than fast.

Shared posture across everything here:

- **Derive the expected answer before the tool shows you one.** A running total you can't falsify
  is not a check. Predict first, then let the software agree or disagree with you.
- **The user drives irreversible actions.** Never type credentials, bank details, or government ID
  numbers; never click submit, file, or pay. Stage the work, present the diff, hand over the click.
- **Verify against generated artifacts, not summary screens.** Summaries are the software's claim
  about itself.

## The roster

| Skill | What it encodes | Use when |
|-------|-----------------|----------|
| [`amend-tax-return`](skills/amend-tax-return/SKILL.md) | Amending a filed tax return in consumer tax software: reconstruct the as-filed baseline, reproduce the filed tax to prove the bracket math, compute the delta by hand, then use the software's running amount-due as a *discriminator*. Employee-stock basis and wash sales; verification against the generated amendment forms. | An omitted or corrected 1099/W-2/K-1 surfaces after filing |

## Scope note

Jurisdiction- and vendor-neutral in structure; each skill has a binding table for the specifics
(forms, brackets, thresholds, statute of limitations). Nothing personal lives here — see the
repo-root rule on personal data.

These are decision-support skills, not professional advice. For anything consequential, the
taxpayer/user makes the call and a licensed professional is the right escalation.
