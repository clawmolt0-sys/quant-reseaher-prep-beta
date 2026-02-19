# B003 Audit Summary

- Problems reviewed: 70
- High urgency (8-10): 21
- Clear duplicate groups flagged:
  - 254 ↔ 306 (Weekend rain probability with dependence assumptions)
  - 568 ↔ 836 (Polya-urn basketball recursion; distribution after 100 attempts)

## Primary quality patterns
- Many entries are under-specified interview notes rather than formal standalone problems.
- Several prompts leak answers or include hints directly in the statement.
- Multiple records contain formatting/encoding corruption or pasted template artifacts.
- Some items depend on missing external context (“Problem 30”, “schema shown above”).

## Recommendation
Prioritize: (1) remove/merge strict duplicates, (2) repair corrupted records, (3) rewrite vague prompts into formal textbook-style specs with explicit I/O and constraints, and (4) enforce standardized solution formatting across the batch.