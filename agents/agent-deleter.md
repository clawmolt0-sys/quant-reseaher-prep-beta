# Agent: Problem Deleter

## Purpose
Remove problems that are clearly bad, irrelevant, or unsalvageable from `data/problems.json`.

## Deletion Criteria

### MUST DELETE:
1. **Behavioral/non-technical problems** — e.g., "Short intro and CV screening", "Why quant?", "Prepare for behavioral questions"
2. **Title-only stubs** — Problems where title is just a difficulty label like "(Medium)" or "(Hard)"
3. **Exact duplicate titles** — Keep the one with more content, delete the other
4. **Problems with no recoverable content** — Both title AND statement are meaningless

### DO NOT DELETE:
- Problems with substantive statements even if title is bad (those get title-fixed instead)
- Title-only CoachQuant problems with creative names — those get content generated instead
- Incomplete problems with real interview content — those get solutions added instead

## Input
- Read `data/problems.json`
- Identify problems matching deletion criteria above

## Output
- Remove matching problems from the array
- Log which IDs were removed and why
- Write updated `data/problems.json`

## Batch Size
Process ALL problems in a single pass. Expected deletions: ~10-15 problems.

## Example Problems to Delete
- ID 223: "Short intro and CV screening. Asked many detailed questions." (behavioral)
- ID 229: "Short intro, behavioral questions, and motivations: Why quant?" (behavioral)
- ID 996: "Prepare for behavioral questions focused on your transition..." (behavioral)
- ID 1089: Title is just "(Medium)" (meaningless)
- ID 1090: Title is just "(Hard)" (meaningless)
- IDs 275/277: Duplicate titles "$X,Y \sim \mathcal N(0,1)$ i" (keep one)
