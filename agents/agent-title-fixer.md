# Agent: Title Fixer

## Purpose
Fix generic, truncated, or broken problem titles in `data/problems.json` by generating descriptive titles from the problem statement content.

## What to Fix

### 1. Generic "Company Problem N" Titles (~117 problems)
Pattern: `two-sigma Problem 1`, `two-sigma Problem 29`, etc.
These all have substantive statements. Generate a concise descriptive title from the statement.

**Title Style Guide:**
- 4-10 words, descriptive of the mathematical concept
- Use title case
- Include key topic keywords (e.g., "Expected Value", "Markov Chain", "Monte Carlo")
- Examples of GOOD titles from existing complete problems:
  - "Sum of Gaussians: Distribution"
  - "Kelly Criterion for Optimal Bet Sizing"
  - "Bayes Theorem: Medical Testing"
  - "Gambler's Ruin with Asymmetric Odds"
  - "Black-Scholes Delta Hedging Strategy"

### 2. Truncated Titles Ending in "..." (~12 problems)
Read the full statement and create a proper short title.

### 3. Broken LaTeX in Titles (~5 problems)
Either fix the LaTeX or replace with a descriptive plain-text title.
Example: `$X,Y,Z \stackrel{i` → "IID Normal Variables: Joint Distribution"

### 4. Single-Word Titles (~4 problems)
Replace with more descriptive titles based on statement content.
Example: ID 704 "Combinatorics" → read statement, make it specific.

## Rules
- NEVER use the pattern "Company Name Problem N"
- NEVER start with "Solve" or "Find" (those are statement words, not title words)
- Titles should tell you what the problem is ABOUT, not what to DO
- Keep LaTeX minimal in titles — prefer plain English. Only use LaTeX for well-known symbols like $\pi$, $e$, $N(0,1)$
- If the statement is about coding, prefix with appropriate label (e.g., "Coding: Merge Intervals" is fine)

## Input
- Read `data/problems.json`
- Process problems matching the criteria above

## Output
- Update the `title` field for each fixed problem
- Write updated `data/problems.json`

## Batch Size
Process in batches of 50-100 problems at a time to manage context. Start with the "two-sigma Problem N" batch (IDs 226-462).
