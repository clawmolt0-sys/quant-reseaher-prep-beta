# B007 Audit Summary

- Total problems reviewed: 70
- Marked as clear duplicates: 23
- High-urgency items (>=8): 33

## Duplicate clusters flagged
- [273, 471, 2708] duplicated-data-effects in OLS
- [853, 486] negative R^2
- [1036, 945, 990, 2579] OLS/MLE derivation basics
- [852, 96, 2685, 2743] OLS assumptions/violations
- [1040, 2782, 1797, 2619] swapping X and Y in simple regression
- [459, 427] adding/derived predictors and coefficient behavior
- [832, 833] single vs multiple predictor error/coefficient comparison
- [875, 706] broad OLS interview-question bundles

## Main quality issues
- Many prompts are conversational or multi-question bundles, not atomic gradable tasks.
- Several items lack explicit assumptions, output format, and boundary conditions.
- Inconsistent formatting and occasional answer leakage reduce agent-parse reliability.
- Company/difficulty/tag metadata appears noisy for some entries.

## Recommendation
Prioritize deduplication and canonicalization of foundational regression prompts (OLS assumptions, coefficient derivation, R^2 behavior). Keep one clean canonical version per concept and convert the rest into structured variants with explicit constraints.