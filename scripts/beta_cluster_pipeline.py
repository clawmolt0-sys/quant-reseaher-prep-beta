#!/usr/bin/env python3
import json
from pathlib import Path
from collections import defaultdict
import numpy as np
from sklearn.cluster import AgglomerativeClustering, DBSCAN
from sklearn.metrics.pairwise import cosine_similarity

ROOT = Path('/home/claw/.openclaw/workspace')
REPO = ROOT / 'quant-researcher-prep'
PROBLEMS_PATH = ROOT / 'quant-researcher-prep_problems.json'
BETA_DIR = REPO / 'audit' / 'beta'
BETA_DIR.mkdir(parents=True, exist_ok=True)

BATCH_IDS = [f'B{i:03d}' for i in range(1, 16)]


def load_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def collect_ids():
    ids = []
    for bid in BATCH_IDS:
        p = REPO / 'audit' / 'batches' / f'{bid}.json'
        if not p.exists():
            continue
        b = load_json(p)
        ids.extend(b.get('problem_ids', []))
    return sorted(set(ids))


def clean_comments(problem_ids):
    # Build one "golden comments" file from B001..B015 outputs.
    # Keep latest comment record per problem id from available batch comments files.
    out = {}
    for bid in BATCH_IDS:
        p = REPO / 'audit' / 'agent_comments' / f'{bid}_comments.json'
        if not p.exists():
            continue
        data = load_json(p)
        arr = data if isinstance(data, list) else data.get('comments', [])
        for row in arr:
            pid = row.get('id')
            if pid in problem_ids:
                out[pid] = row
    rows = [out[i] for i in sorted(out.keys())]
    # minimal cleaning metadata
    for r in rows:
        c = r.get('comment', '')
        r['comment_quality'] = {
            'char_len': len(c),
            'is_templated_risk': ('standard interview problem in algorithms/data structures' in c.lower())
        }
    (BETA_DIR / 'golden_comments_B001_B015.json').write_text(json.dumps({
        'count': len(rows),
        'source_batches': BATCH_IDS,
        'comments': rows
    }, indent=2))
    return rows


def embed_problem_texts(problem_ids, problems):
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer('all-MiniLM-L6-v2')
    texts = []
    kept_ids = []
    for pid in problem_ids:
        p = problems.get(pid)
        if not p:
            continue
        title = p.get('title', '')
        stmt = p.get('statement', '')
        sol = p.get('solution', '')
        text = f"Title: {title}\nStatement: {stmt}\nSolution: {sol[:1200]}"
        texts.append(text)
        kept_ids.append(pid)
    emb = model.encode(texts, normalize_embeddings=True, show_progress_bar=True)
    return kept_ids, np.array(emb)


def cluster_and_bucket(ids, emb):
    # Full N x N cosine matrix
    sim = cosine_similarity(emb)
    np.save(BETA_DIR / 'cosine_matrix.npy', sim)

    # Agglomerative on cosine distance
    dist = 1 - sim
    agg = AgglomerativeClustering(metric='precomputed', linkage='average', distance_threshold=0.18, n_clusters=None)
    labels_agg = agg.fit_predict(dist)

    # DBSCAN as alternative
    db = DBSCAN(metric='cosine', eps=0.12, min_samples=2)
    labels_db = db.fit_predict(emb)

    def to_clusters(labels, name):
        d = defaultdict(list)
        for pid, lb in zip(ids, labels):
            d[int(lb)].append(pid)
        clusters = []
        for lb, members in d.items():
            members = sorted(members)
            # bucket to 1..10 items as requested
            if len(members) <= 10:
                clusters.append({'cluster_id': f'{name}-{lb}', 'problem_ids': members})
            else:
                for i in range(0, len(members), 10):
                    clusters.append({'cluster_id': f'{name}-{lb}-{i//10+1}', 'problem_ids': members[i:i+10]})
        return clusters

    clusters_agg = to_clusters(labels_agg, 'agg')
    clusters_db = to_clusters(labels_db, 'db')

    (BETA_DIR / 'clusters_agglomerative.json').write_text(json.dumps({
        'method': 'AgglomerativeClustering',
        'distance_threshold': 0.18,
        'item_count': len(ids),
        'cluster_count': len(clusters_agg),
        'clusters': clusters_agg
    }, indent=2))

    (BETA_DIR / 'clusters_dbscan.json').write_text(json.dumps({
        'method': 'DBSCAN',
        'eps': 0.12,
        'item_count': len(ids),
        'cluster_count': len(clusters_db),
        'clusters': clusters_db
    }, indent=2))

    return sim, clusters_agg, clusters_db


def eval_with_duplicate_flags(ids, clusters, comments):
    # weak benchmark: duplicate flags from comments should co-locate in same cluster
    pid_to_cluster = {}
    for c in clusters:
        for pid in c['problem_ids']:
            pid_to_cluster[pid] = c['cluster_id']

    flagged = []
    for row in comments:
        pid = row.get('id')
        for d in row.get('duplicate_candidates', []) or []:
            if isinstance(d, int):
                flagged.append((pid, d))
    if not flagged:
        metrics = {'flagged_pairs': 0, 'co_cluster_rate': None}
    else:
        ok = sum(1 for a, b in flagged if pid_to_cluster.get(a) == pid_to_cluster.get(b))
        metrics = {'flagged_pairs': len(flagged), 'co_cluster_pairs': ok, 'co_cluster_rate': ok / len(flagged)}

    (BETA_DIR / 'cluster_eval_against_flags.json').write_text(json.dumps(metrics, indent=2))
    return metrics


def write_llm_prompt_template():
    prompt = '''You are an expert quantitative researcher evaluating a cluster of potential duplicate interview problems.
Carefully read all problems in the provided cluster.
Determine if they are asking for the exact same mathematical solution.
Pay strict attention to numbers, constraints, probability distributions, and specific financial or mathematical terminology.
If ANY problem in this cluster differs in its mathematical core, constraints, or numbers, you MUST separate it out.
Output a JSON object containing the perfectly formatted canonical version(s) of the problem(s).
If there are two distinct mathematical problems in the cluster, output two distinct canonical problems.

Required JSON schema:
{
  "cluster_id": "...",
  "canonical_problems": [
    {
      "canonical_title": "...",
      "canonical_problem_statement": "... textbook-style, formal, no leaked solution",
      "input_output_spec": "...",
      "constraints": ["..."],
      "solution_outline": {
        "approach": "...",
        "intuition": "...",
        "correctness": "...",
        "complexity": "...",
        "implementation_notes": "..."
      },
      "source_problem_ids": [1,2,3]
    }
  ]
}
'''
    (BETA_DIR / 'canonicalization_prompt_template.txt').write_text(prompt)


def main():
    problems_raw = load_json(PROBLEMS_PATH)
    problems = {p['id']: p for p in problems_raw}
    ids = collect_ids()
    comments = clean_comments(ids)
    kept_ids, emb = embed_problem_texts(ids, problems)
    sim, c_agg, c_db = cluster_and_bucket(kept_ids, emb)
    metrics = eval_with_duplicate_flags(kept_ids, c_agg, comments)
    write_llm_prompt_template()

    summary = {
        'unique_problem_count_testset': len(kept_ids),
        'agglomerative_cluster_count': len(c_agg),
        'dbscan_cluster_count': len(c_db),
        'eval': metrics,
        'outputs': [
            'audit/beta/golden_comments_B001_B015.json',
            'audit/beta/cosine_matrix.npy',
            'audit/beta/clusters_agglomerative.json',
            'audit/beta/clusters_dbscan.json',
            'audit/beta/cluster_eval_against_flags.json',
            'audit/beta/canonicalization_prompt_template.txt'
        ]
    }
    (BETA_DIR / 'README.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
