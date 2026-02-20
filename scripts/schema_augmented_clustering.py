#!/usr/bin/env python3
import json, math
from pathlib import Path
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

ROOT=Path('/home/claw/.openclaw/workspace/quant-researcher-prep')
DATA=ROOT/'data'/'problems.json'
SCHEMAS=ROOT/'audit'/'schemas_merged.json'
OUT=ROOT/'audit'/'beta_full_schema'
OUT.mkdir(parents=True, exist_ok=True)

MAX_CLUSTER_SIZE=10
TARGET_MIN, TARGET_MAX = 1000, 2000

def jload(p):
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))

def jdump(p,obj):
    Path(p).write_text(json.dumps(obj,indent=2,ensure_ascii=False))

def normalize_pair(a,b):
    return (a,b) if a<b else (b,a)

def build_flagged_pairs():
    pairs=set()
    for i in range(1,16):
        fp=ROOT/'audit'/'agent_comments'/f'B{i:03d}_comments.json'
        if not fp.exists():
            continue
        d=jload(fp)
        arr=d if isinstance(d,list) else d.get('comments',[])
        for r in arr:
            a=r.get('id')
            for b in (r.get('duplicate_candidates') or []):
                if isinstance(a,int) and isinstance(b,int) and a!=b:
                    pairs.add(normalize_pair(a,b))
    return pairs

def connected_components(sim, ids, tau):
    n=len(ids)
    vis=np.zeros(n,dtype=bool)
    comps=[]
    for i in range(n):
        if vis[i]: continue
        stack=[i]; vis[i]=True; comp=[i]
        while stack:
            x=stack.pop()
            neigh=np.where(sim[x]>=tau)[0]
            for y in neigh:
                if not vis[y]:
                    vis[y]=True; stack.append(y); comp.append(y)
        comps.append(comp)
    return comps

def split_comp(comp, sim, max_size=10):
    if len(comp)<=max_size: return [comp]
    sub=sim[np.ix_(comp,comp)]
    med=int(np.argmax(sub.sum(axis=1)))
    order=[c for _,c in sorted(zip(sub[med],comp), reverse=True)]
    return [order[i:i+max_size] for i in range(0,len(order),max_size)]

def clusters_from_tau(sim, ids, tau):
    out=[]; cid=1
    for c in connected_components(sim,ids,tau):
        for p in split_comp(c,sim,MAX_CLUSTER_SIZE):
            out.append({'cluster_id':f'C{cid:04d}','problem_ids':sorted([ids[i] for i in p])})
            cid+=1
    return out

def main():
    problems=jload(DATA)
    schemas=jload(SCHEMAS)['records']
    schema_by_id={r['problem_id']:r.get('schema_text','') for r in schemas if isinstance(r,dict) and isinstance(r.get('problem_id'),int)}

    ids=[p['id'] for p in problems]
    pmap={p['id']:p for p in problems}

    texts=[]
    for pid in ids:
        p=pmap[pid]
        title=p.get('title','')
        stmt=p.get('statement','')
        sol=(p.get('solution','') or '')[:800]
        fp=(p.get('fingerprint','') or '')
        schema=schema_by_id.get(pid,'')
        txt=f"Title: {title}\nStatement: {stmt}\nSolution: {sol}\nFingerprint: {fp}\nSchema: {schema}"
        texts.append(txt)

    from sentence_transformers import SentenceTransformer
    model=SentenceTransformer('all-MiniLM-L6-v2')
    emb=np.array(model.encode(texts, normalize_embeddings=True, show_progress_bar=True),dtype=np.float32)
    sim=cosine_similarity(emb)

    flagged=build_flagged_pairs()
    # threshold sweep for precision proxy > 90%
    thresholds=[round(x,3) for x in np.arange(0.80,0.991,0.01)]
    rows=[]
    for t in thresholds:
        idx=np.where(np.triu(sim,1)>=t)
        pred=[normalize_pair(ids[i],ids[j]) for i,j in zip(idx[0],idx[1])]
        pset=set(pred)
        if len(pset)==0:
            rows.append({'threshold':t,'predicted_pairs':0,'hits':0,'precision_proxy':None,'recall_proxy':0.0})
            continue
        hits=len(pset & flagged)
        precision=hits/len(pset)
        recall=hits/len(flagged) if flagged else 0.0
        rows.append({'threshold':t,'predicted_pairs':len(pset),'hits':hits,'precision_proxy':precision,'recall_proxy':recall})

    viable=[r for r in rows if r['precision_proxy'] is not None and r['precision_proxy']>=0.9]
    if viable:
        # maximize recall then predicted_pairs
        best=sorted(viable,key=lambda r:(r['recall_proxy'], r['predicted_pairs']), reverse=True)[0]
    else:
        best=sorted([r for r in rows if r['precision_proxy'] is not None], key=lambda r:r['precision_proxy'], reverse=True)[0]

    tau=best['threshold']
    clusters=clusters_from_tau(sim,ids,tau)

    # choose alternate tau to hit 1000-2000 clusters if needed
    if not (TARGET_MIN <= len(clusters) <= TARGET_MAX):
        cand=[]
        for r in rows:
            c=clusters_from_tau(sim,ids,r['threshold'])
            cand.append((abs((TARGET_MIN+TARGET_MAX)/2-len(c)), r['threshold'], len(c), c, r))
        cand.sort(key=lambda x:x[0])
        _,tau,_,clusters,row_sel=cand[0]
        best=row_sel

    jdump(OUT/'threshold_sweep.json', {'flagged_pair_count':len(flagged),'results':rows,'selected':best})
    jdump(OUT/'clusters_schema_augmented.json', {'threshold':tau,'cluster_count':len(clusters),'clusters':clusters})

    summary={
        'problem_count':len(ids),
        'flagged_pairs':len(flagged),
        'selected_threshold':tau,
        'selected_precision_proxy':best['precision_proxy'],
        'selected_recall_proxy':best['recall_proxy'],
        'selected_predicted_pairs':best['predicted_pairs'],
        'cluster_count':len(clusters),
        'target_cluster_range':[TARGET_MIN,TARGET_MAX]
    }
    jdump(OUT/'summary.json', summary)
    print(json.dumps(summary, indent=2))

if __name__=='__main__':
    main()
