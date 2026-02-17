# Agent: Content Cleaner

## Purpose
Fix metadata, categories, ratings, and formatting issues in `data/problems.json`.

## What to Fix

### 1. Category Mismatches (~26 problems)
Problems about coding/algorithms categorized as "probability" or wrong category.
- Read the statement and assign the correct category from: `probability`, `statistics`, `linear-algebra`, `stochastic-calculus`, `finance`, `coding`, `brain-teaser`, `combinatorics`, `optimization`, `game-theory`
- If statement mentions LeetCode, coding, algorithms, data structures → category should be `coding`
- If statement mentions options, Black-Scholes, Greeks, bonds → category should be `finance`

### 2. Rating Normalization
Current ratings:
- Complete problems: 3 (easy), 5 (medium), 8 (hard) — CORRECT
- Incomplete problems: 1200 — WRONG, should be 3/5/8 based on difficulty
- Title-only problems: 3 — should match difficulty

Rule: `rating = difficulty === 'easy' ? 3 : difficulty === 'hard' ? 8 : 5`

### 3. Difficulty Assignment for Uniform Problems
All 587 CoachQuant problems are marked `medium`. Adjust based on title keywords:
- Words suggesting easy: "basic", "simple", "coin flip", "dice roll", "fair coin"
- Words suggesting hard: "optimal strategy", "martingale", "stochastic", "PDE", "measure"
- Otherwise keep medium

### 4. Company Field Sync
Ensure `company` (array) and `companies` (array) fields are identical for every problem.
Some problems have mismatched values.

### 5. Type Assignment
Many problems have `type: "calculation"` as default. Review statement and assign better type from:
`calculation`, `proof`, `estimation`, `coding`, `conceptual`, `brain-teaser`, `strategy`

### 6. Tags/Subtopics Population
For problems with statements but empty tags/subtopics, extract relevant tags from the statement text.
Common tags: `expected-value`, `conditional-probability`, `bayes-theorem`, `markov-chain`, `normal-distribution`, `monte-carlo`, `dynamic-programming`, `options-pricing`, `regression`, `hypothesis-testing`, `linear-algebra`, `combinatorics`, `game-theory`

## Input
- Read `data/problems.json`

## Output
- Update metadata fields as described
- Write updated `data/problems.json`

## Batch Size
Process ALL problems in one pass for metadata fixes (ratings, company sync).
Process 100 at a time for category and type reclassification.
