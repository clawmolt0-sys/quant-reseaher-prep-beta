/* ============================================
   DATA LOADER — Fetch and cache JSON data
   ============================================ */

const DataLoader = (() => {
  const cache = {};

  async function load(file) {
    if (cache[file]) return cache[file];
    try {
      const resp = await fetch(`data/${file}`);
      if (!resp.ok) throw new Error(`Failed to load ${file}: ${resp.status}`);
      const data = await resp.json();
      cache[file] = data;
      return data;
    } catch (err) {
      console.error(`DataLoader: ${err.message}`);
      return null;
    }
  }

  return {
    problems:  () => load('problems.json'),
    lectures:  () => load('lectures.json'),
    labs:      () => load('labs.json'),
    topics:    () => load('topics.json'),
    companies: () => load('companies.json'),
    tags:      () => load('tags.json'),
  };
})();
