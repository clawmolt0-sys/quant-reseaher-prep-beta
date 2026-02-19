# B015 Audit Summary

Total problems reviewed: 70
High-urgency items (>=8): 10

## Clear duplicate pairs flagged
- 730 ↔ 794 (uniform point in unit circle generation)
- 46 ↔ 1012 (acute triangle from 3 random points on a circle)
- 35 ↔ 817 (stick cut at two random points; triangle probability)
- 762 ↔ 77 (expected chord intersections from random points on a circle)

## Recurring quality issues
- Missing formal I/O and constraint specification in many statements.
- Metadata/tag inconsistency (many entries have null topics).
- Statement/solution boundary violations in some prompts (embedded answer or explicit formula).
- Mixed general-form and fixed-parameter wording without a clear contract.

## Recommendation
Standardize all B015 prompts into a consistent format: Formal Problem Statement, Inputs/Outputs, Constraints, and separated Solution section. Merge or remove clear duplicates listed above to reduce dataset redundancy.
