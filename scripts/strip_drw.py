"""
Strip DRW-specific references from Jupyter notebooks.

Usage:
    python strip_drw.py <input_dir> <output_dir>

This script:
1. Removes "DRW New-Hire Learning Program" headers
2. Strips all *.xd.drw URLs (Webworm, Tickster, docs)
3. Removes credentials.py imports
4. Removes contact info cells
5. Skips excluded folders entirely
"""

import json
import os
import re
import sys
import shutil
from pathlib import Path


# Folders to exclude entirely
EXCLUDE_FOLDERS = {
    'WebwormTickster(GarethReeves)',
    'Compliance(RobArmour)',
    'ClosingRemarks(TD-Dave)',
    '.ipynb_checkpoints',
    '__pycache__',
    'conda-meta',
}

# Files to exclude
EXCLUDE_FILES = {
    'credentials.py',
    'webworm-links.md',
}

# Patterns to remove from cell sources
STRIP_PATTERNS = [
    # DRW program headers
    (r'DRW\s+New-Hire\s+Learning\s+Program', 'Quant Researcher Prep'),
    (r'DRW\s+Talent\s+Development', 'Quant Research Training'),
    # Internal URLs
    (r'https?://[\w.-]+\.xd\.drw\S*', '[internal link removed]'),
    (r'https?://webworm\S*', '[internal link removed]'),
    (r'https?://tickster\S*', '[internal link removed]'),
    (r'https?://docs\.xd\.drw\S*', '[internal link removed]'),
    (r'https?://md\.xd\.drw\S*', '[internal link removed]'),
    # Credential imports
    (r'from\s+sample_repo\.credentials\s+import\s+\*', '# credentials removed'),
    (r'from\s+sample_repo\s+import\s+credentials', '# credentials removed'),
    (r'import\s+credentials', '# credentials removed'),
    # Contact info (be careful not to remove useful academic contacts)
    (r'Contact:\s*[\w.]+@drw\.com', ''),
    # DRW mentions in general text
    (r'\bDRW\b(?!\s*(Trading|Holdings))', 'the firm'),
]

# Cells that are mostly DRW branding (remove entirely if they match)
REMOVE_CELL_PATTERNS = [
    r'^\s*#\s*DRW\s+New-Hire',
    r'^\s*#\s*DRW\s+Talent',
    r'^\s*<img.*drw.*logo',
]


def should_exclude_path(path: Path) -> bool:
    """Check if any part of the path matches an excluded folder."""
    for part in path.parts:
        if part in EXCLUDE_FOLDERS:
            return True
    return False


def strip_notebook(input_path: Path, output_path: Path):
    """Process a single notebook, stripping DRW references."""
    with open(input_path, 'r', encoding='utf-8') as f:
        try:
            nb = json.load(f)
        except json.JSONDecodeError:
            print(f"  SKIP (invalid JSON): {input_path}")
            return False

    modified = False
    new_cells = []

    for cell in nb.get('cells', []):
        source = ''.join(cell.get('source', []))

        # Check if the entire cell should be removed
        should_remove = False
        for pattern in REMOVE_CELL_PATTERNS:
            if re.search(pattern, source, re.IGNORECASE | re.MULTILINE):
                should_remove = True
                break

        if should_remove:
            modified = True
            continue  # Skip this cell entirely

        # Apply substitution patterns
        new_source = source
        for pattern, replacement in STRIP_PATTERNS:
            new_source = re.sub(pattern, replacement, new_source, flags=re.IGNORECASE)

        if new_source != source:
            modified = True
            # Rebuild the source as a list of lines (preserving notebook format)
            cell['source'] = new_source.splitlines(True)
            if cell['source'] and not cell['source'][-1].endswith('\n'):
                pass  # Last line doesn't need \n

        new_cells.append(cell)

    nb['cells'] = new_cells

    # Write output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(nb, f, indent=1, ensure_ascii=False)

    return modified


def process_directory(input_dir: Path, output_dir: Path):
    """Process all notebooks in input_dir, writing cleaned versions to output_dir."""
    stats = {'processed': 0, 'modified': 0, 'skipped': 0, 'copied': 0}

    for root, dirs, files in os.walk(input_dir):
        root_path = Path(root)
        relative = root_path.relative_to(input_dir)

        # Skip excluded folders
        if should_exclude_path(relative):
            print(f"  EXCLUDE: {relative}")
            stats['skipped'] += 1
            continue

        for filename in files:
            if filename in EXCLUDE_FILES:
                stats['skipped'] += 1
                continue

            input_file = root_path / filename
            output_file = output_dir / relative / filename

            if filename.endswith('.ipynb'):
                # Process notebook
                was_modified = strip_notebook(input_file, output_file)
                stats['processed'] += 1
                if was_modified:
                    stats['modified'] += 1
                    print(f"  MODIFIED: {relative / filename}")
                else:
                    print(f"  CLEAN:    {relative / filename}")
            else:
                # Copy other files as-is (data, images, etc.)
                output_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(input_file, output_file)
                stats['copied'] += 1

    return stats


def main():
    if len(sys.argv) < 3:
        print("Usage: python strip_drw.py <input_dir> <output_dir>")
        print("Example: python strip_drw.py ../dump/code ./processed_code")
        sys.exit(1)

    input_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])

    if not input_dir.exists():
        print(f"Error: Input directory '{input_dir}' does not exist.")
        sys.exit(1)

    print(f"Processing notebooks from: {input_dir}")
    print(f"Output to: {output_dir}")
    print("=" * 60)

    stats = process_directory(input_dir, output_dir)

    print("=" * 60)
    print(f"Done!")
    print(f"  Notebooks processed: {stats['processed']}")
    print(f"  Notebooks modified:  {stats['modified']}")
    print(f"  Files copied:        {stats['copied']}")
    print(f"  Items skipped:       {stats['skipped']}")


if __name__ == '__main__':
    main()
