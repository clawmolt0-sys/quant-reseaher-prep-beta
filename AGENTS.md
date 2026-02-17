# QR Prep — Agent Instructions & Project Status

## Overview
Quant Researcher Prep (QR Prep) is a static GitHub Pages site for quant interview preparation.
- **Live URL**: `https://alacrity2001.github.io/quant-researcher-prep/`
- **Repo**: `C:\Users\alexw\Documents\Quant Finance Prep\site\` (git root)
- **Dump**: `C:\Users\alexw\Documents\Quant Finance Prep\dump\` (raw problem files, NOT in git)
- **Hosting**: GitHub Pages from `master` branch

## Tech Stack
- **Frontend**: Vanilla HTML/CSS/JS (no framework, no build step)
- **Auth**: Firebase Auth compat SDK v10.12.0 (Google + GitHub OAuth)
- **Database**: Firestore for user data (stats, XP, level, streak, favorites, collections, achievements)
- **Math**: KaTeX for LaTeX rendering
- **Module Pattern**: IIFE (`const Module = (() => { ... return { ... }; })()`)
- **CSS**: BEM naming (`.block__element--modifier`), CSS variables in `css/variables.css`

## Important Constraints
- **No Node.js / Python** available in the build environment
- PowerShell is available but has tricky escaping from bash
- Write PowerShell scripts to `.ps1` files, then run with `powershell -ExecutionPolicy Bypass -File script.ps1`
- Problems are stored in a single JSON file (`data/problems.json`) — currently 1,673 problems
- The JSON file is large (~5MB compressed). For bulk operations, use PowerShell scripts, not inline edits.

## Directory Structure
```
site/
├── index.html              # Homepage (hero, stats, about, FAQ, logo carousel)
├── problems.html           # Problem list + detail view
├── explore.html            # Explore by company
├── learn.html              # Learning tracks
├── cheatsheet.html         # Formulas, tips (replaces old resources.html)
├── profile.html            # User profile page
├── css/
│   ├── variables.css       # Design tokens (colors, spacing, typography)
│   ├── layout.css          # Grid, nav, footer
│   ├── components.css      # Cards, badges, tags, buttons, hero
│   ├── problem.css         # Problem list and detail page styles
│   ├── auth.css            # Auth modal, user dropdown, collections, action bar
│   ├── explore.css         # Explore page
│   ├── profile.css         # Profile page
│   └── cheatsheet.css      # Cheat sheet page
├── js/
│   ├── firebase-config.js  # Firebase init (projectId: qrprep)
│   ├── app.js              # Shared init, nav, routing helpers
│   ├── theme.js            # Dark/light theme toggle
│   ├── auth.js             # Auth module (sign in, user doc, tier, waitForAuth)
│   ├── data-loader.js      # DataLoader cache pattern for JSON files
│   ├── problems.js         # Problem list, detail, filters, random mode
│   ├── explore.js          # Company explore page
│   ├── learn.js            # Learning tracks
│   ├── collections.js      # User problem lists (Save to List)
│   ├── achievements.js     # Badge/achievement system
│   └── profile.js          # Profile page rendering
├── data/
│   ├── problems.json       # All problems (1,673 entries)
│   ├── companies.json      # Company metadata (152 companies)
│   ├── tags.json           # Difficulty/category/type tag definitions
│   └── topics.json         # Learning topic tracks
└── agents/
    ├── agent-deleter.md
    ├── agent-title-fixer.md
    ├── agent-content-cleaner.md
    ├── agent-solutionizer.md
    └── agent-problem-generator.md
```

## Problem Schema
Each problem in `data/problems.json` has these fields:

```json
{
  "id": 42,                          // Unique integer ID
  "title": "The Secretary Problem",  // Display title
  "statement": "You interview...",   // Problem text (may contain LaTeX)
  "solution": "The optimal...",      // Solution text (may contain LaTeX)
  "hints": ["Think about...", ...],  // Array of hint strings
  "difficulty": "medium",            // "easy" | "medium" | "hard"
  "category": "probability",         // "probability" | "statistics" | "finance" | "coding" | "general"
  "type": "calculation",             // "calculation" | "open-ended" | "brain-teaser" | "coding" | "estimation" | "proof" | "strategy" | "conceptual"
  "topics": ["probability"],         // Array of topic slugs
  "subtopics": ["optimal-stopping"], // Array of subtopic slugs
  "tags": ["probability", "optimization"],
  "companies": ["tower-research"],   // Array of company slugs (canonical)
  "company": "tower-research",       // Legacy single company field (synced with companies[0])
  "source": "original",              // Source identifier
  "rating": 5,                       // Difficulty rating 1-10 (3=easy, 5=medium, 8=hard)
  "status": "complete",              // "complete" | "incomplete" | "title-only"
  "generated": false,                // true if AI-generated content
  "fingerprint": "..."               // (NEW) Normalized 15-token description for dedup
}
```

### Status meanings:
- `"complete"` — Has statement + solution, fully ready
- `"incomplete"` — Has statement but no/partial solution
- `"title-only"` — Only has title, no real content (from CoachQuant batch import)

### Type definitions:
- `"calculation"` — Standard math with definite numeric/formula answer
- `"open-ended"` — Discussion/design/explain questions
- `"brain-teaser"` — Logic puzzles, riddles
- `"coding"` — Algorithm/DS implementation
- `"estimation"` — Fermi estimation, market sizing
- `"proof"` — Formal mathematical proofs
- `"strategy"` — Game theory, optimal strategies
- `"conceptual"` — Understanding concepts, definitions

## Key Auth Flow
1. `Auth.init()` → Firebase `onAuthStateChanged` fires
2. `handleAuthStateChanged(user)` → immediate `renderUserUI()`, then loads Firestore doc
3. After Firestore loads → re-renders UI with full data, dispatches `auth-state-changed` event
4. `Auth.waitForAuth()` — Promise that resolves when auth fully settles
5. `authSettled` flag + callback queue pattern

### Tier System
- `"free"` — Default, limited to problems with `id <= 200`
- `"pro"` — Access all problems. Admin emails hardcoded in `getTier()`.
- Check: `Auth.getTier()` returns `"pro"` or `"free"`

## Problem Dedup Strategy
### Fingerprint System
Each problem has a `fingerprint` field — a normalized 15-token canonical description using this template:
```
{domain} | {core_task} | {key_objects} | {technique} | {output_type} | {constraints}
```

**Fields:**
- `domain`: probability, statistics, linear-algebra, calculus, combinatorics, coding, finance, stochastic-processes
- `core_task`: compute, maximize, minimize, prove, simulate, design, estimate, explain
- `key_objects`: main mathematical objects (dice, coins, brownian-motion, matrix, regression, etc.)
- `technique`: primary solving technique (linearity-of-expectation, dynamic-programming, bayes, etc.)
- `output_type`: number, formula, probability, algorithm, proof, explanation
- `constraints`: any notable constraints or parameters

### Dedup Pipeline
1. **Exact match**: Same fingerprint → definite duplicate
2. **Fuzzy lexical match**: >80% token overlap in fingerprint → likely duplicate candidate
3. **Semantic match**: Similar domain + core_task + key_objects → candidate for review
4. **LLM confirmation**: For top ~30 candidates, use LLM to confirm duplicate vs variant
5. **Relationship types**: `duplicate`, `variant` (like Buy/Sell Stock I, II, III), `related`

### Knowledge Graph (Future)
- Nodes: problems, concepts
- Edges: `duplicate_of`, `variant_of`, `uses_concept`, `related_to`
- Store in `data/problem-graph.json`

## Dump Directory (Raw Problem Sources)
```
dump/
├── all problem - Copy/
│   ├── Citadel/main.tex
│   ├── Citadel_20240923/main.tex
│   ├── citadel_new/main.tex
│   ├── drw/main.tex              # 7 problems with solutions + rubrics
│   ├── DRW_questions/main.tex    # 3 problems (subset of drw/)
│   ├── extracted/
│   ├── HFT/
│   ├── HRT_math/
│   ├── jump_trading/
│   ├── SIG/
│   ├── squarepoint/
│   ├── tower/main.tex            # 42 problems
│   └── two_sigma/
├── all problem/
├── code/
├── problems/
└── slides/
```

## Current Known Issues
1. Many `title-only` problems (IDs ~1093-1679) have garbage titles from CoachQuant import
2. Some `incomplete` problems are duplicates of existing `complete` problems (e.g., Tower #643-683 duplicate existing Tower problems)
3. Problems.json is a flat file — consider migration to structured format if it grows beyond ~3000 problems
4. No solution for problems imported from dump without explicit solutions

## Git Commits (Recent)
- `ee622a5` — UX overhaul: LeetCode dropdown, action bar, random nav, type fixes
- `1eeb5c5` — Problem overhaul + auth/profile reliability fix
- `8299c86` — Fix nav consistency, profile loading, random bias, restore logo carousel
- `63cd805` — Major UX overhaul: fix auth bugs, redesign homepage, add cheat sheet
