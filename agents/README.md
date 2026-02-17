# Problem Pipeline Agents

Reusable agent prompts for cleaning, enriching, and maintaining the QR Prep problem database.

## Agent Types

| Agent | File | Purpose |
|---|---|---|
| **Deleter** | `agent-deleter.md` | Remove bad/irrelevant problems (behavioral, duplicates, unsalvageable stubs) |
| **Title Fixer** | `agent-title-fixer.md` | Fix generic, truncated, or broken titles |
| **Content Cleaner** | `agent-content-cleaner.md` | Fix formatting, templates, category mismatches, metadata |
| **Solutionizer** | `agent-solutionizer.md` | Generate solutions, hints, and subtopics for incomplete problems |
| **Problem Generator** | `agent-problem-generator.md` | Generate real problem content for title-only stubs |

## Running Agents

Each agent operates on a batch of problems from `data/problems.json`. They read the file, process their batch, and write the updated file back.

Agents can be run in parallel on different ID ranges to avoid conflicts.

## Priority Order

1. Deleter (remove junk first)
2. Title Fixer (fix names)
3. Content Cleaner (fix metadata, categories, ratings)
4. Problem Generator (fill in title-only stubs)
5. Solutionizer (add solutions to incomplete problems)
