# Audit Summary — B001

- Problems reviewed: **70**
- High-urgency items (8-10): **2**
- Problems flagged with clear duplicate candidates: **2**
- Problems needing substantial rewrite/standardization: **25**

## Duplicate flags
- #1901 ↔ #1903 (high-confidence near-duplicate, same core combinatorics/cards structure)

## General quality pattern
- A large share of entries use informal/interview-chat title phrasing instead of canonical problem naming.
- Many statements are short and omit explicit input/output contracts and assumptions.
- Solutions often need stronger sectioning for parser-friendly consumption.

## Recommendation
Standardize all retained problems into a strict template: Formal Title → Problem Statement (definitions, assumptions, constraints, I/O, examples) → Solution (Approach, Intuition, Correctness, Complexity, Code Notes). Merge/remove duplicate variants in series-style entries.
