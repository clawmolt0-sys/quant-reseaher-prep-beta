# Audit Summary — B005

Total problems reviewed: 70

## High-priority items (urgency >= 8)
- #1961 — Longer Piece II (Urgency 8): Depends on prior problem and references external part
- #1960 — Longer Piece I (Urgency 8): Major quality issue
- #2605 — Explain Variance To A Client Who Know (Urgency 9): Open-ended communication prompt without evaluation rubric
- #2840 — Sample Points Randomly From A Unit Sphere (Urgency 9): Answer leakage + vague wording
- #2599 — What Is The Formula Of Sharpe Ratio (Urgency 10): Not a valid single problem (multi-question prompt + glossary request)
- #2817 — Through All The Interviews: Deriving Simple Regressions (Urgency 10): Not a problem statement (experience note / topic list)

## Duplicate flags
- #1961 ↔ [1960] — Near-duplicate multipart pair with identical setup; only target metric changes (expectation vs variance of the longer piece). Consider merging as Part (a)/(b) in one canonical problem.
- #1960 ↔ [1961] — Near-duplicate multipart pair with identical setup; only target metric changes (expectation vs variance of the longer piece). Consider merging as Part (a)/(b) in one canonical problem.

## Common remediation themes
- Normalize to formal textbook prompts (variables, domains, assumptions, explicit asks).
- Remove embedded hints/answers from statements.
- Standardize solution formatting into concise derivation steps.
- Clarify rounding/output requirements and edge-case conventions.
