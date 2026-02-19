# B012 Audit Summary

- Total problems audited: 70
- High urgency (8-10): 22
- Medium urgency (5-7): 48
- Low urgency (1-4): 0
- Flagged duplicate clusters: 4

## Key Findings
- A large share of entries use placeholder statements (e.g., "Solve this ...") with missing formal specs.
- Several items have no solution content; these require full authoring before platform use.
- Existing solutions are often mathematically plausible but need consistent structure and clearer separation from prompts.
- Duplicate flags were kept strict and only applied when semantic overlap was very high and naming/framing was near-identical.

## Recommended Batch Action
1. Prioritize all urgency ≥8 items for full rewrite (formal prompt + structured solution).
2. Run side-by-side review for flagged duplicate candidates and merge where no substantive new constraint exists.
3. Enforce a publication template: Title, Statement, Input/Output, Constraints, Example, Approach, Correctness, Complexity, Code/Math notes.
