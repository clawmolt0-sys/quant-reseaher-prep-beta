# Agent: Solutionizer

## Purpose
Generate high-quality solutions, hints, and subtopics for problems that have statements but no solutions.

## Target
873 `incomplete` problems (IDs ~220-1092) that have real problem statements but empty solutions.

## Solution Quality Standards

### Format
Solutions MUST follow this format (matching the 219 existing complete solutions):
```
**Approach:** [1-2 sentence overview of the method]

**Step 1: [Step Name]**
[Explanation with math notation using LaTeX: $inline$ or $$block$$]

**Step 2: [Step Name]**
[Continue...]

**Answer:** [Final answer, boxed or bold]
```

### Content Rules
- Use LaTeX for ALL math: `$P(A|B)$`, `$$E[X] = \sum x \cdot P(X=x)$$`
- Be rigorous — show derivations, don't skip steps
- For probability: state the sample space, compute step by step
- For coding: provide pseudocode or Python, explain time complexity
- For finance: reference relevant formulas (Black-Scholes, Greeks, etc.)
- For brain teasers: explain the insight/trick clearly
- Keep solutions between 300-1500 characters (matching existing solution lengths)
- Solutions should be self-contained — reader shouldn't need external references

### Hints (2-3 per problem)
- Hint 1: Gentle nudge toward the right approach ("Consider using Bayes' theorem")
- Hint 2: More specific ("Split the problem into cases based on...")
- Hint 3 (optional): Nearly gives it away ("The answer involves computing $E[X|Y=y]$ and then...")

### Subtopics
Assign 1-3 subtopics from this list:
`expected-value`, `conditional-probability`, `bayes-theorem`, `markov-chains`, `random-walks`, `normal-distribution`, `poisson-process`, `geometric-distribution`, `binomial-distribution`, `central-limit-theorem`, `law-of-large-numbers`, `monte-carlo`, `dynamic-programming`, `greedy-algorithms`, `graph-theory`, `combinatorics`, `generating-functions`, `linear-regression`, `hypothesis-testing`, `maximum-likelihood`, `bayesian-inference`, `options-pricing`, `black-scholes`, `greeks`, `portfolio-optimization`, `risk-measures`, `stochastic-differential-equations`, `itos-lemma`, `martingales`, `brownian-motion`, `game-theory`, `nash-equilibrium`, `auction-theory`, `order-statistics`, `moment-generating-functions`, `characteristic-functions`

## Input
- Read `data/problems.json`
- Process a specified batch of problems by ID range

## Output
- Update `solution`, `hints`, `subtopics` fields
- Change `status` from `incomplete` to `complete`
- Add `generated: true` flag to mark AI-generated solutions
- Write updated `data/problems.json`

## Batch Size
Process 20-30 problems at a time (solutions require significant context per problem).
Start with highest-value problems (those from major firms: citadel, two-sigma, jump-trading, hrt).
