# B005 QA Summary

Total reviewed: 70

## Top urgent items (urgency 8-10)

- **2599 — What Is The Formula Of Sharpe Ratio** (urgency 10)
  - Issue: Break multi-topic prompt into separate assessable questions
  - Action: Current item combines unrelated interview concepts. Split into separate problems: Sharpe ratio formula, mean-variance optimization objective, and definition/examples of black swan events.
  - Possible duplicates: 2747, 2604, 2808

- **2605 — Explain Variance To A Client Who Know** (urgency 10)
  - Issue: Convert interview prompt into a concrete quantitative question
  - Action: This entry is open-ended and not assessable. Replace with a specific task, for example: 'Given a portfolio return distribution with mean 8% and standard deviation 12%, explain variance in plain language and interpret one-standard-deviation risk in dollars for a $1M portfolio.'
  - Possible duplicates: 2705, 2192, 2699

- **2817 — Through All The Interviews: Deriving Simple Regressions** (urgency 10)
  - Issue: Rewrite as a complete, grammatically correct problem set
  - Action: Current text is not a full question. Replace with explicit tasks: derive OLS slope/intercept, compute bias and variance of estimators under classical assumptions, and interpret correlation vs covariance in portfolio context.
  - Possible duplicates: 976, 464, 2192

- **2592 — Show That The Variance Of The Sum** (urgency 9)
  - Issue: Replace with a precise theorem-style title
  - Action: Current item is phrased as an instruction rather than a problem. Rewrite it as: 'Variance of a Sum of Independent Random Variables'. State assumptions clearly (finite second moments, independence) and ask for a proof of Var(X+Y)=Var(X)+Var(Y).
  - Possible duplicates: 2591, 1941, 2840

- **2840 — Sample Points Randomly From A Unit Sphere** (urgency 9)
  - Issue: Split into clear sub-questions on sphere sampling
  - Action: Current text is fragmented. Rewrite into explicit parts: (a) sample uniformly on S^2, (b) transform to uniform variables, (c) justify uniformity. Define whether sampling is on the surface or in the volume.
  - Possible duplicates: 2592, 2591, 2780

- **2022 — Sumdard Deviation** (urgency 8)
  - Issue: Fix title typo and align with content
  - Action: Rename 'Sumdard Deviation' to 'Standard Deviation of a Sum of Draws'. Ensure statement defines the card values unambiguously (likely 1 through n) and specifies sampling with replacement across sets.
  - Possible duplicates: 2191, 1941, 2192

- **2591 — How Can You Generate Two Random Variables** (urgency 8)
  - Issue: Specify a constructive correlation-generation problem
  - Action: Rewrite as a formal construction problem: 'Given independent standard normals Z1,Z2 and target correlation rho in (-1,1), construct X,Y with Var(X)=Var(Y)=1 and Corr(X,Y)=rho.' Include what must be shown.
  - Possible duplicates: 2592, 2840, 1941

## Next priority items (urgency 7)

- 1960 — Longer Piece I: Rename to descriptive title without sequel marker
- 1961 — Longer Piece II: Rename to descriptive variance-focused title
- 2148 — MrBeast's Coin Challenge: Remove pop-culture tone and formalize random mechanism
- 2249 — Maxiunif: Use standard terminology for order statistics
- 2250 — Miniunif: Use standard terminology for order statistics
- 2496 — Andrew Tate's Elevator I: Use neutral title and clearer setup
- 2575 — X Is A Normal Random Variable With: Remove conversational wording and make the probability task exact
