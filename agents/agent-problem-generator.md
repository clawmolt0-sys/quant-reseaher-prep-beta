# Agent: Problem Generator

## Purpose
Generate real problem statements for title-only CoachQuant stubs, based on the title and company context.

## Target
587 `title-only` problems (IDs 1093-1679) from CoachQuant that have creative names but no content.

## Approach
For each title-only problem:
1. Read the creative title (e.g., "Noodle Knot Loop", "Token Tango")
2. Read the company tag (e.g., "optiver", "jane-street", "citadel")
3. Read the assigned category and type
4. Generate a realistic quant interview problem that:
   - Matches the style of that company's known interview questions
   - Fits the assigned category (probability, statistics, etc.)
   - Is inspired by the creative title (interpret it loosely)
   - Is at appropriate difficulty for the company

## Problem Quality Standards

### Statement
- 100-400 characters
- Clear, concise, self-contained
- Include specific numbers/parameters (not vague)
- Use LaTeX for math: `$P(X > 3)$`, `$E[N]$`
- Match the style of existing complete problems (IDs 1-219)

### Example Transformations
- Title: "Noodle Knot Loop" at Optiver → A problem about random knots/loops in probability
- Title: "Token Tango" at Jane Street → A problem about token exchange/game theory
- Title: "Decay Dive" at Citadel → A problem about exponential decay/radioactive process
- Title: "Big Mac Math" at Two Sigma → An estimation/Fermi problem

### Solution (300-1500 chars)
Same format as agent-solutionizer.md — structured with steps, LaTeX, final answer.

### Hints (2-3)
Same format as agent-solutionizer.md.

### Metadata Updates
- Update `statement` with real content
- Update `solution` with full solution
- Update `hints` with 2-3 hints
- Update `subtopics` with relevant subtopics
- Change `status` from `title-only` to `complete`
- Set `generated: true` (this IS AI-generated content based on real interview titles)
- Adjust `difficulty` if the generated content warrants it
- Assign appropriate `type` (calculation, proof, estimation, etc.)

## Input
- Read `data/problems.json`
- Process a specified batch by ID range

## Output
- Update all fields listed above
- Write updated `data/problems.json`

## Batch Size
Process 15-25 problems at a time (generating full problems requires significant context).
Start with problems from major firms (Citadel, Jane Street, Optiver, Two Sigma, Five Rings).
