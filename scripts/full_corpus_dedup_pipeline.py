#!/usr/bin/env python3
import json, math
from pathlib import Path
from collections import defaultdict, deque
import numpy as np
from sklearn.cluster import AgglomerativeClustering, DBSCAN
from sklearn.metrics.pairwise import cosine_similarity

ROOT = Path('/home/claw/.openclaw/workspace/quant-researcher-prep')
DATA = ROOT / 'data'
OUT = ROOT / 'audit' / 'beta_full'
OUT.mkdir(parents=True, exist_ok=True)

TARGET_MIN = 1000
TARGET_MAX = 1500
TARGET_MID = 1250
MAX_CLUSTER_SIZE = 10


def jload(p):
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))

def jdump(p, obj):
    Path(p).write_text(json.dumps(obj, indent=2, ensure_ascii=False))

def build_text(p):
    title = p.get('title','')
    stmt = p.get('statement','')
    sol = (p.get('solution','') or '')[:1200]
    tags = ', '.join((p.get('tags') or [])[:8])
    return f"Title: {title}\nCategory: {p.get('category','')}\nType: {p.get('type','')}\nTags: {tags}\nStatement: {stmt}\nSolution: {sol}"

def quality_score(p):
    title = (p.get('title') or '').strip()
    stmt = (p.get('statement') or '').strip()
    sol = (p.get('solution') or '').strip()
    bad = 0
    low = (title + ' ' + stmt).lower()
    for kw in ['leetcode', 'lc ', 'variation', 'coding question', 'problem x', 'see above', 'tbd', 'todo']:
        if kw in low:
            bad += 1
    return len(stmt)*0.6 + len(sol)*0.3 + len(title)*0.1 - bad*200

def connected_components_from_threshold(sim, ids, tau):
    n = len(ids)
    vis = np.zeros(n, dtype=bool)
    comps = []
    for i in range(n):
        if vis[i]:
            continue
        q = [i]
        vis[i] = True
        comp = [i]
        while q:
            x = q.pop()
            neigh = np.where(sim[x] >= tau)[0]
            for y in neigh:
                if not vis[y]:
                    vis[y] = True
                    q.append(y)
                    comp.append(y)
        comps.append(comp)
    return comps

def split_large_component(comp, sim, max_size=10):
    if len(comp) <= max_size:
        return [comp]
    # medoid-based chunking
    sub = sim[np.ix_(comp, comp)]
    medoid_local = int(np.argmax(sub.sum(axis=1)))
    center = sub[medoid_local]
    order = [c for _, c in sorted(zip(center, comp), reverse=True)]
    return [order[i:i+max_size] for i in range(0, len(order), max_size)]

def count_clusters_for_tau(sim, ids, tau):
    comps = connected_components_from_threshold(sim, ids, tau)
    k = 0
    for c in comps:
        k += math.ceil(len(c)/MAX_CLUSTER_SIZE)
    return k

def choose_tau(sim, ids):
    grid = [0.92,0.9,0.88,0.86,0.84,0.82,0.8,0.78,0.76,0.74,0.72,0.7,0.68,0.66,0.64,0.62]
    best = None
    for tau in grid:
        k = count_clusters_for_tau(sim, ids, tau)
        diff = abs(k - TARGET_MID)
        if best is None or diff < best[0]:
            best = (diff, tau, k)
        if TARGET_MIN <= k <= TARGET_MAX:
            return tau, k
    return best[1], best[2]

def create_clusters(sim, ids, tau):
    comps = connected_components_from_threshold(sim, ids, tau)
    clusters = []
    cid = 1
    for comp in comps:
        for part in split_large_component(comp, sim, MAX_CLUSTER_SIZE):
            members = [ids[i] for i in part]
            clusters.append({'cluster_id': f'C{cid:04d}', 'problem_ids': sorted(members)})
            cid += 1
    return clusters

def evaluate_against_testflags(clusters):
    pid2c = {}
    for c in clusters:
        for pid in c['problem_ids']:
            pid2c[pid] = c['cluster_id']
    flagged = []
    for b in range(1,16):
        p = ROOT / 'audit' / 'agent_comments' / f'B{b:03d}_comments.json'
        if not p.exists():
            continue
        arr = jload(p)
        if isinstance(arr, dict):
            arr = arr.get('comments', [])
        for r in arr:
            a = r.get('id')
            for d in (r.get('duplicate_candidates') or []):
                if isinstance(d, int):
                    flagged.append((a,d))
    if not flagged:
        return {'flagged_pairs':0, 'co_cluster_rate':None}
    ok = sum(1 for a,b in flagged if pid2c.get(a)==pid2c.get(b))
    return {'flagged_pairs':len(flagged), 'co_cluster_pairs':ok, 'co_cluster_rate':ok/len(flagged)}

def build_canonical_dataset(problems, index, clusters):
    pmap = {p['id']:p for p in problems}
    imap = {x['id']:x for x in index}
    reduced = []
    reduced_index = []
    mapping = []
    for c in clusters:
        ids = c['problem_ids']
        existing = [pmap[i] for i in ids if i in pmap]
        if not existing:
            continue
        best = max(existing, key=quality_score)
        canon = dict(best)
        canon['merged_from'] = [p['id'] for p in existing if p['id'] != best['id']]
        canon['cluster_id'] = c['cluster_id']
        reduced.append(canon)
        if best['id'] in imap:
            ix = dict(imap[best['id']])
            reduced_index.append(ix)
        mapping.append({'cluster_id': c['cluster_id'], 'canonical_id': best['id'], 'members': ids})
    reduced.sort(key=lambda x: x['id'])
    reduced_index.sort(key=lambda x: x['id'])
    return reduced, reduced_index, mapping

def main():
    problems = jload(DATA/'problems.json')
    index = jload(DATA/'problems-index.json')

    ids = [p['id'] for p in problems]
    pmap = {p['id']:p for p in problems}

    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer('all-MiniLM-L6-v2')
    texts = [build_text(pmap[i]) for i in ids]
    emb = model.encode(texts, normalize_embeddings=True, show_progress_bar=True)
    emb = np.array(emb, dtype=np.float32)

    sim = cosine_similarity(emb)
    np.save(OUT/'cosine_matrix_full.npy', sim.astype(np.float16))

    tau, k = choose_tau(sim, ids)
    clusters = create_clusters(sim, ids, tau)

    # also run requested methods for record
    dist = 1 - sim
    agg = AgglomerativeClustering(metric='precomputed', linkage='average', distance_threshold=(1-tau), n_clusters=None)
    labels_agg = agg.fit_predict(dist)
    db = DBSCAN(metric='cosine', eps=(1-tau), min_samples=2).fit_predict(emb)

    # compact labels output
    jdump(OUT/'labels_agglomerative.json', {'distance_threshold': float(1-tau), 'labels': labels_agg.tolist()})
    jdump(OUT/'labels_dbscan.json', {'eps': float(1-tau), 'labels': db.tolist()})

    reduced, reduced_index, mapping = build_canonical_dataset(problems, index, clusters)

    # overwrite beta site data files in-place
    jdump(DATA/'problems.beta.backup.meta.json', {
        'original_problem_count': len(problems),
        'original_index_count': len(index)
    })
    jdump(DATA/'problems.json', reduced)
    jdump(DATA/'problems-index.json', reduced_index)

    eval_metrics = evaluate_against_testflags(clusters)

    jdump(OUT/'clusters_full.json', {'tau': tau, 'cluster_count': len(clusters), 'clusters': clusters})
    jdump(OUT/'canonical_mapping.json', {'count': len(mapping), 'mapping': mapping})
    jdump(OUT/'evaluation_testset_duplicates.json', eval_metrics)

    # prompts for cluster-level LLM canonicalization (step 5)
    prompt_base = (
        'You are an expert quantitative researcher evaluating a cluster of potential duplicate interview problems. '
        'Carefully read all problems in the provided cluster. Determine if they are asking for the exact same mathematical solution. '
        'Pay strict attention to numbers, constraints, probability distributions, and specific financial or mathematical terminology. '
        'If ANY problem in this cluster differs in its mathematical core, constraints, or numbers, you MUST separate it out. '
        'Output a JSON object containing the perfectly formatted canonical version(s) of the problem(s). '
        'If there are two distinct mathematical problems in the cluster, output two distinct canonical problems.'
    )
    llm_jobs = []
    for c in clusters:
        if len(c['problem_ids']) <= 1:
            continue
        items = []
        for pid in c['problem_ids']:
            p = pmap.get(pid)
            if not p:
                continue
            items.append({'id': pid, 'title': p.get('title',''), 'statement': p.get('statement',''), 'solution': (p.get('solution','') or '')[:1200]})
        llm_jobs.append({'cluster_id': c['cluster_id'], 'prompt': prompt_base, 'problems': items})
    jdump(OUT/'llm_canonicalization_jobs.json', {'job_count': len(llm_jobs), 'jobs': llm_jobs})

    summary = {
        'full_problem_count': len(problems),
        'target_cluster_range': [TARGET_MIN, TARGET_MAX],
        'selected_tau': tau,
        'final_cluster_count': len(clusters),
        'reduced_problem_count': len(reduced),
        'reduction_ratio': round(len(reduced)/len(problems),4),
        'testset_duplicate_eval': eval_metrics,
        'beta_site_updated_files': ['data/problems.json','data/problems-index.json'],
        'llm_jobs_count': len(llm_jobs)
    }
    jdump(OUT/'summary.json', summary)
    print(json.dumps(summary, indent=2))

if __name__ == '__main__':
    main()
