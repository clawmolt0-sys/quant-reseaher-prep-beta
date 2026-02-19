# Audit Summary — B013

- Problems reviewed: 70
- High urgency (8-10): 40
- Duplicate flags raised: 12

## Key findings

1. A large fraction of prompts are underspecified placeholder-style items (e.g., 'Solve this puzzle ...') and are not independently solvable without hidden context.
2. Several entries appear to be near-duplicates of existing bank items (coin odd-heads variants, PCA explainers, uniform-sampling-in-circle, generic regression explainer).
3. Formatting quality is inconsistent: mixed interview notes, bundled multi-question dumps, and occasional encoding artifacts reduce agent/human readability.

## Recommended remediation

- Enforce a strict authoring template: formal statement, explicit IO, constraints, edge cases, and example.
- Separate multi-part interview recollections into atomic standalone problems.
- De-duplicate by concept+solution pattern; keep one canonical version and add only genuine variants with new constraints.
- Standardize solution formatting to: Approach → Intuition → Correctness → Complexity → Code Notes.
