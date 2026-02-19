# Problem Ingestion Pipeline

Reusable pipeline for adding new problems from PDFs or other sources.

## Prerequisites

- PowerShell 5.1+
- `pdftotext` (from poppler, available at `C:\Program Files\Git\mingw64\bin\pdftotext.exe`)
- All scripts in `site/scripts/`
- Data files in `site/data/`

## Pipeline Steps

### 1. Extract Problems from Source

**PDFs:** Use `convert-pdfs.ps1`
- Edit `$pdfConfigs` array to add new PDF entries
- Specify: path, company slug, format (numbered/topic-task/problem-n), role (QR/QT/SWE)
- Output: `data/ingest/pdf-converted.json`

```powershell
powershell -File scripts/convert-pdfs.ps1
```

**GitHub repos / JSON:** Use `merge-corpus.ps1`
- Place converted JSON files in `data/ingest/`
- Format: array of `{title, statement, solution, category, difficulty, companies, tags}`

### 2. Dedup Existing DB (Optional, First Time)

Run before adding new problems to clean existing duplicates:

```powershell
powershell -File scripts/dedup-existing.ps1
```

Uses: graph edges (weight >= 0.85) + title Jaccard + statement prefix matching.
Three tiers: auto-merge (>= 0.95), likely dup (>= 0.90), flagged (>= 0.85).

### 3. Merge with Aggressive Dedup

```powershell
powershell -File scripts/merge-pdfs.ps1
```

Multi-layer dedup:
1. **Title fingerprint** - exact normalized title match
2. **Statement prefix** - first 100 chars normalized
3. **Title Jaccard** - word overlap >= 0.7 with statement confirmation
4. **Keyword similarity** - from expand-graph Get-Similarity logic

When dup found: skip new problem, merge company tag into survivor.

### 4. Second-Pass Dedup

Catch cross-source duplicates among newly-added problems:

```powershell
powershell -File scripts/dedup-new.ps1
```

### 5. Classify Roles

```powershell
powershell -File scripts/add-roles.ps1
```

Assigns QR/QT/SWE based on category + keyword analysis.

### 6. Generate Solutions (for incomplete problems)

Write solutions in batches to `data/ingest/solutions-*.json`:
```json
[{"id": 123, "solution": "## Solution\n..."}, ...]
```

Then apply:
```powershell
powershell -File scripts/apply-all-solutions.ps1
```

### 7. Expand Knowledge Graph

```powershell
powershell -File scripts/expand-graph.ps1
```

Only processes complete problems not already in graph.

### 8. Rebuild Everything

```powershell
powershell -File scripts/rebuild-index.ps1
powershell -File scripts/rebuild-chunks.ps1
powershell -File scripts/clean-graph.ps1
```

### 9. Bump Cache & Deploy

In `js/data-loader.js`, increment `CACHE_VERSION`.

```bash
git add -A && git commit -m "Add N new problems from [source]" && git push
```

## Key Data Files

| File | Description |
|------|-------------|
| `data/problems.json` | Main problem database |
| `data/problems-index.json` | Compact index for list view |
| `data/problems/*.json` | Per-category chunks for detail view |
| `data/companies.json` | Company metadata |
| `data/similarity-graph.json` | Knowledge graph (edges + concepts) |
| `data/ingest/*.json` | Intermediate ingestion files |

## Dedup Tips

- The graph-based approach (`dedup-existing.ps1`) is most effective AFTER the knowledge graph has been expanded
- Title Jaccard >= 0.7 catches most duplicates; combined with statement prefix >= 0.5 reduces false positives
- Always merge company tags from duplicates into survivors before marking as duplicate
- Cross-PDF duplicates are common (same classic problems asked at multiple firms)
