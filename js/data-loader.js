/* ============================================
   DATA LOADER — Fetch, cache (memory + localStorage), lazy load
   ============================================
   Strategy:
   - problems-index.json (~260KB) for list view — loaded first, cached aggressively
   - problems.json (~2.7MB) loaded lazily only when a detail view is opened
   - All data cached in memory + sessionStorage for instant subsequent loads
   - sessionStorage survives page navigations within the same tab
   ============================================ */

const DataLoader = (() => {
  const memCache = {};
  const STORAGE_PREFIX = 'qr-data-';
  const CACHE_VERSION = 'v3'; // bump to invalidate cache

  // ---- SessionStorage helpers ----
  function storageGet(key) {
    try {
      const raw = sessionStorage.getItem(STORAGE_PREFIX + key);
      if (!raw) return null;
      const obj = JSON.parse(raw);
      if (obj._v !== CACHE_VERSION) {
        sessionStorage.removeItem(STORAGE_PREFIX + key);
        return null;
      }
      return obj.data;
    } catch (e) { return null; }
  }

  function storageSet(key, data) {
    try {
      sessionStorage.setItem(STORAGE_PREFIX + key, JSON.stringify({ _v: CACHE_VERSION, data }));
    } catch (e) {
      // Storage full — clear old entries and try again
      try {
        for (let i = sessionStorage.length - 1; i >= 0; i--) {
          const k = sessionStorage.key(i);
          if (k && k.startsWith(STORAGE_PREFIX)) sessionStorage.removeItem(k);
        }
        sessionStorage.setItem(STORAGE_PREFIX + key, JSON.stringify({ _v: CACHE_VERSION, data }));
      } catch (e2) { /* give up */ }
    }
  }

  // ---- Core loader with caching ----
  async function load(file, opts) {
    opts = opts || {};

    // 1. Memory cache (instant)
    if (memCache[file]) return memCache[file];

    // 2. SessionStorage cache (very fast, ~5ms)
    if (!opts.skipStorage) {
      const cached = storageGet(file);
      if (cached) {
        memCache[file] = cached;
        return cached;
      }
    }

    // 3. Network fetch
    try {
      const resp = await fetch('data/' + file);
      if (!resp.ok) throw new Error('Failed to load ' + file + ': ' + resp.status);
      const data = await resp.json();
      memCache[file] = data;

      // Cache in sessionStorage (skip large files > 4MB)
      if (!opts.skipStorage) {
        storageSet(file, data);
      }

      return data;
    } catch (err) {
      console.error('[DataLoader]', err.message);
      return null;
    }
  }

  // ---- Problem-specific loaders ----

  // Lightweight index for list/table view (~260KB)
  function problemsIndex() { return load('problems-index.json'); }

  // Full problems data for detail view (~2.7MB) — loaded lazily
  // Too large for sessionStorage, so skip storage caching
  let fullProblemsPromise = null;
  function problemsFull() {
    if (memCache['problems.json']) return Promise.resolve(memCache['problems.json']);
    if (!fullProblemsPromise) {
      fullProblemsPromise = load('problems.json', { skipStorage: true });
    }
    return fullProblemsPromise;
  }

  // Preload full data in background (called after initial render)
  function preloadFullProblems() {
    if (memCache['problems.json']) return;
    // Use requestIdleCallback if available, else setTimeout
    const fn = () => { problemsFull(); };
    if (typeof requestIdleCallback === 'function') {
      requestIdleCallback(fn, { timeout: 5000 });
    } else {
      setTimeout(fn, 1000);
    }
  }

  // Get a single problem's full data by ID
  async function problemById(id) {
    id = typeof id === 'number' ? id : parseInt(id, 10);
    const full = await problemsFull();
    if (!full) return null;
    return full.find(p => p.id === id) || null;
  }

  // Backwards compat — returns full problems (but prefer problemsIndex for list)
  function problems() { return problemsFull(); }

  return {
    problems,
    problemsIndex,
    problemsFull,
    problemById,
    preloadFullProblems,
    lectures:      () => load('lectures.json'),
    labs:          () => load('labs.json'),
    topics:        () => load('topics.json'),
    companies:     () => load('companies.json'),
    tags:          () => load('tags.json'),
    featuredLists: () => load('featured-lists.json'),
    // Expose for cache busting
    clearCache: () => {
      Object.keys(memCache).forEach(k => delete memCache[k]);
      for (let i = sessionStorage.length - 1; i >= 0; i--) {
        const k = sessionStorage.key(i);
        if (k && k.startsWith(STORAGE_PREFIX)) sessionStorage.removeItem(k);
      }
    },
  };
})();
