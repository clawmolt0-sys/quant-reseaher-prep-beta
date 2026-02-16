/* ============================================
   PROBLEMS — LeetCode-style problem list + detail
   ============================================ */

const Problems = (() => {
  let allProblems = [];
  let tagsData = null;
  let companiesData = null;
  let currentSort = { key: 'id', dir: 'asc' };

  // ---- Normalize: handle both old and new schema ----
  function ensureArray(val) {
    if (!val) return [];
    if (Array.isArray(val)) return val;
    return [val]; // PowerShell flattens single-element arrays to strings
  }

  function normalize(p) {
    return {
      id:        typeof p.id === 'number' ? p.id : parseInt(String(p.id).replace(/\D/g, ''), 10),
      title:     p.title,
      statement: p.statement || p.question || '',
      solution:  p.solution || '',
      hints:     ensureArray(p.hints),
      companies: ensureArray(p.companies || p.company),
      tags:      ensureArray(p.tags || p.subtopics),
      category:  p.category || (p.topics && p.topics[0]) || 'probability',
      difficulty:p.difficulty || 'medium',
      rating:    p.rating || diffToRating(p.difficulty),
      type:      p.type || 'closed-form',
      source:    p.source || 'interview',
    };
  }

  function diffToRating(d) {
    return d === 'easy' ? 3 : d === 'hard' ? 8 : 5;
  }

  // ---- Init ----
  async function init() {
    const raw = (await DataLoader.problems()) || [];
    allProblems = raw.map(normalize);
    tagsData = (await DataLoader.tags()) || { categories: [], types: [] };
    companiesData = (await DataLoader.companies()) || [];

    const params = App.getParams();
    if (params.id) {
      renderDetail(parseInt(params.id, 10) || params.id);
    } else {
      renderList(params);
    }
  }

  // ---- Category metadata ----
  function getCatMeta(catId) {
    if (!tagsData || !tagsData.categories) return { name: catId, icon: '📄', color: '#6366f1' };
    return tagsData.categories.find(c => c.id === catId) || { name: catId, icon: '📄', color: '#6366f1' };
  }

  // ---- Company name lookup ----
  function companyName(id) {
    const c = companiesData.find(co => co.id === id);
    return c ? c.name : id;
  }

  function companyShort(id) {
    const map = {
      'citadel': 'Citadel', 'two-sigma': 'Two Sigma', 'de-shaw': 'D.E. Shaw',
      'jump-trading': 'Jump', 'drw': 'DRW', 'hrt': 'HRT', 'jane-street': 'Jane St',
      'optiver': 'Optiver', 'sig': 'SIG', 'squarepoint': 'Squarepoint',
      'tower-research': 'Tower', 'millennium': 'Millennium', 'point72': 'Point72',
      'aqr': 'AQR', 'renaissance': 'RenTech', 'five-rings': 'Five Rings', 'hft': 'HFT',
    };
    return map[id] || id;
  }

  // ---- List View ----
  function renderList(params) {
    const container = document.getElementById('content');
    if (!container) return;

    // Count per category
    const catCounts = {};
    allProblems.forEach(p => {
      catCounts[p.category] = (catCounts[p.category] || 0) + 1;
    });

    // Build category list from tags.json
    const categories = (tagsData.categories || []).filter(c => catCounts[c.id]);

    // Filter
    let filtered = [...allProblems];
    const activeCat = params.category || params.topic || null;
    const activeCompany = params.company || null;
    const activeDiff = params.difficulty || null;
    const activeType = params.type || null;
    const searchQ = params.q || '';

    if (activeCat) filtered = filtered.filter(p => p.category === activeCat);
    if (activeCompany) filtered = filtered.filter(p => p.companies.includes(activeCompany));
    if (activeDiff) filtered = filtered.filter(p => p.difficulty === activeDiff);
    if (activeType) filtered = filtered.filter(p => p.type === activeType);
    if (searchQ) {
      const q = searchQ.toLowerCase();
      filtered = filtered.filter(p =>
        p.title.toLowerCase().includes(q) ||
        p.statement.toLowerCase().includes(q) ||
        p.tags.some(t => t.toLowerCase().includes(q))
      );
    }

    // Sort
    sortProblems(filtered, currentSort.key, currentSort.dir);

    // Build header text
    let headerText = 'All Problems';
    if (activeCat) {
      const cm = getCatMeta(activeCat);
      headerText = `${cm.icon} ${cm.name}`;
    }

    container.innerHTML = `
      <div class="container">
        <div class="problems-layout">

          <!-- Sidebar -->
          <aside class="problems-sidebar">
            <div class="sidebar__title">Categories</div>
            <div class="sidebar__categories">
              <button class="sidebar__cat-btn ${!activeCat ? 'sidebar__cat-btn--active' : ''}"
                onclick="Problems.filterCat(null)">
                <span>All Problems</span>
                <span class="sidebar__cat-count">${allProblems.length}</span>
              </button>
              ${categories.map(c => `
                <button class="sidebar__cat-btn ${activeCat === c.id ? 'sidebar__cat-btn--active' : ''}"
                  onclick="Problems.filterCat('${c.id}')">
                  <span><span class="sidebar__cat-icon">${c.icon}</span>${c.name}</span>
                  <span class="sidebar__cat-count">${catCounts[c.id] || 0}</span>
                </button>
              `).join('')}
            </div>

            <div class="sidebar__divider"></div>
            <div class="sidebar__title">Difficulty</div>
            <div class="sidebar__categories">
              ${['easy','medium','hard'].map(d => `
                <button class="sidebar__cat-btn ${activeDiff === d ? 'sidebar__cat-btn--active' : ''}"
                  onclick="Problems.filterDiff('${d}')">
                  <span><span class="diff-dot diff-${d}"></span>${d.charAt(0).toUpperCase()+d.slice(1)}</span>
                  <span class="sidebar__cat-count">${allProblems.filter(p=>p.difficulty===d).length}</span>
                </button>
              `).join('')}
            </div>

            <div class="sidebar__divider"></div>
            <div class="sidebar__title">Type</div>
            <div class="sidebar__categories">
              ${(tagsData.types || []).filter(t => allProblems.some(p=>p.type===t.id)).map(t => `
                <button class="sidebar__cat-btn ${activeType === t.id ? 'sidebar__cat-btn--active' : ''}"
                  onclick="Problems.filterType('${t.id}')">
                  <span>${t.name}</span>
                  <span class="sidebar__cat-count">${allProblems.filter(p=>p.type===t.id).length}</span>
                </button>
              `).join('')}
            </div>
          </aside>

          <!-- Main -->
          <div class="problems-main">
            <div class="problems-header">
              <h1 class="problems-header__title">${headerText}</h1>
              <p class="problems-header__subtitle">Practice problems from real quant interviews. Click a problem to see the solution.</p>
            </div>

            <!-- Mobile category selector -->
            <div class="mobile-cat-filter">
              <select onchange="Problems.filterCat(this.value || null)">
                <option value="">All Categories</option>
                ${categories.map(c => `<option value="${c.id}" ${activeCat===c.id?'selected':''}>${c.icon} ${c.name} (${catCounts[c.id]})</option>`).join('')}
              </select>
            </div>

            <div class="pf-bar">
              <input type="text" class="pf-bar__search" id="search"
                placeholder="Search problems..." value="${App.escapeHtml(searchQ)}">
              <select class="pf-bar__select" id="filter-company">
                <option value="">All Companies</option>
                ${companiesData.map(c =>
                  `<option value="${c.id}" ${activeCompany===c.id?'selected':''}>${c.name}</option>`
                ).join('')}
              </select>
              <span class="pf-bar__count">${filtered.length} of ${allProblems.length}</span>
            </div>

            <table class="problem-table">
              <thead>
                <tr>
                  <th class="th-num" onclick="Problems.sort('id')">#${sortArrow('id')}</th>
                  <th class="th-title" onclick="Problems.sort('title')">Title${sortArrow('title')}</th>
                  <th class="th-cat" onclick="Problems.sort('category')">Category${sortArrow('category')}</th>
                  <th class="th-diff" onclick="Problems.sort('difficulty')">Difficulty${sortArrow('difficulty')}</th>
                  <th class="th-type" onclick="Problems.sort('type')">Type${sortArrow('type')}</th>
                  <th class="th-rating" onclick="Problems.sort('rating')">Rating${sortArrow('rating')}</th>
                </tr>
              </thead>
              <tbody>
                ${filtered.map(p => tableRow(p)).join('')}
              </tbody>
            </table>

            ${filtered.length === 0 ? `
              <div class="empty-state">
                <div class="empty-state__icon">🔍</div>
                <div class="empty-state__title">No problems found</div>
                <p>Try adjusting your filters.</p>
              </div>
            ` : ''}
          </div>

        </div>
      </div>
    `;

    // Bind events
    document.getElementById('filter-company').addEventListener('change', (e) => {
      const p = App.getParams();
      p.company = e.target.value || null;
      App.setParams(p);
      renderList(p);
    });

    let searchTimeout;
    document.getElementById('search').addEventListener('input', (e) => {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(() => {
        const p = App.getParams();
        p.q = e.target.value || null;
        App.setParams(p);
        renderList(p);
      }, 300);
    });
  }

  function tableRow(p) {
    const catMeta = getCatMeta(p.category);
    const tagHtml = p.tags.slice(0, 3).map(t =>
      `<span class="td-tag">${formatTag(t)}</span>`
    ).join('');

    return `
      <tr>
        <td class="td-num">${p.id}</td>
        <td>
          <a class="td-title-link" href="problems.html?id=${p.id}">${App.escapeHtml(p.title)}</a>
          <div class="td-tags">${tagHtml}</div>
        </td>
        <td><span class="cat-pill" style="background:${catMeta.color}15;color:${catMeta.color}">${catMeta.icon} ${catMeta.name}</span></td>
        <td class="td-diff"><span class="diff-dot diff-${p.difficulty}"></span><span class="diff-label">${p.difficulty}</span></td>
        <td class="td-type">${formatType(p.type)}</td>
        <td class="td-rating">${p.rating}/10</td>
      </tr>
    `;
  }

  // ---- Sorting ----
  function sortProblems(arr, key, dir) {
    const mult = dir === 'asc' ? 1 : -1;
    arr.sort((a, b) => {
      let va = a[key], vb = b[key];
      if (key === 'difficulty') {
        const order = { easy: 1, medium: 2, hard: 3 };
        va = order[va] || 2;
        vb = order[vb] || 2;
      }
      if (typeof va === 'string') return va.localeCompare(vb) * mult;
      return (va - vb) * mult;
    });
  }

  function sortArrow(key) {
    if (currentSort.key !== key) return '<span class="sort-arrow">↕</span>';
    return currentSort.dir === 'asc'
      ? '<span class="sort-arrow sort-arrow--active">↑</span>'
      : '<span class="sort-arrow sort-arrow--active">↓</span>';
  }

  // ---- Detail View ----
  function renderDetail(id) {
    const container = document.getElementById('content');
    if (!container) return;

    const problem = allProblems.find(p => p.id === id || p.id === parseInt(id, 10));
    if (!problem) {
      container.innerHTML = `
        <div class="container">
          <div class="empty-state">
            <div class="empty-state__icon">❓</div>
            <div class="empty-state__title">Problem not found</div>
            <a href="problems.html" class="btn btn--primary mt-4">Back to Problems</a>
          </div>
        </div>
      `;
      return;
    }

    const idx = allProblems.indexOf(problem);
    const prev = idx > 0 ? allProblems[idx - 1] : null;
    const next = idx < allProblems.length - 1 ? allProblems[idx + 1] : null;
    const catMeta = getCatMeta(problem.category);

    const companyHtml = problem.companies.map(c =>
      `<a class="company-tag" href="problems.html?company=${c}">${companyShort(c)}</a>`
    ).join('');

    const tagHtml = problem.tags.map(t =>
      `<a class="detail-tag" href="problems.html?q=${encodeURIComponent(t)}">${formatTag(t)}</a>`
    ).join('');

    const hintsHtml = problem.hints && problem.hints.length > 0
      ? `<div class="problem-detail__hints">
          ${problem.hints.map((h, i) => `
            <div class="hint-item">
              <button class="hint-toggle" onclick="Problems.toggleHint(this)">
                <span class="solution-toggle__arrow">▶</span> Hint ${i + 1}
              </button>
              <div class="hint-content math-content">${h}</div>
            </div>
          `).join('')}
        </div>`
      : '';

    container.innerHTML = `
      <div class="container">
        <div class="breadcrumbs">
          <a href="problems.html">Problems</a>
          <span class="breadcrumbs__sep"></span>
          <a href="problems.html?category=${problem.category}">${catMeta.icon} ${catMeta.name}</a>
          <span class="breadcrumbs__sep"></span>
          <span>#${problem.id}</span>
        </div>

        <div class="problem-detail">
          <div class="problem-detail__header">
            <div class="problem-detail__num">#${problem.id} · ${formatType(problem.type)} · Rating ${problem.rating}/10</div>
            <h1 class="problem-detail__title">${App.escapeHtml(problem.title)}</h1>
            <div class="problem-detail__meta">
              <span class="diff-dot diff-${problem.difficulty}"></span>
              <span class="diff-label">${problem.difficulty}</span>
              <span class="cat-pill" style="background:${catMeta.color}15;color:${catMeta.color}">${catMeta.icon} ${catMeta.name}</span>
              <div class="company-tags">${companyHtml}</div>
            </div>
            <div class="problem-detail__tags-row">${tagHtml}</div>
          </div>

          <div class="problem-detail__statement math-content">
            ${problem.statement}
          </div>

          ${hintsHtml}

          <div class="problem-detail__solution">
            <button class="solution-toggle" onclick="Problems.toggleSolution(this)">
              <span class="solution-toggle__arrow">▶</span> Show Solution
            </button>
            <div class="solution-content math-content">
              ${problem.solution}
            </div>
          </div>

          <div class="problem-detail__nav">
            ${prev
              ? `<a class="problem-nav-btn" href="problems.html?id=${prev.id}">← #${prev.id} ${App.escapeHtml(prev.title)}</a>`
              : '<span></span>'
            }
            ${next
              ? `<a class="problem-nav-btn" href="problems.html?id=${next.id}">#${next.id} ${App.escapeHtml(next.title)} →</a>`
              : '<span></span>'
            }
          </div>
        </div>
      </div>
    `;

    KatexRender.render(container);
  }

  // ---- Filter helpers ----
  function filterCat(cat) {
    const p = App.getParams();
    p.category = cat;
    p.topic = null; // clear old param
    App.setParams(p);
    renderList(p);
  }

  function filterDiff(d) {
    const p = App.getParams();
    p.difficulty = p.difficulty === d ? null : d;
    App.setParams(p);
    renderList(p);
  }

  function filterType(t) {
    const p = App.getParams();
    p.type = p.type === t ? null : t;
    App.setParams(p);
    renderList(p);
  }

  // ---- Toggle helpers ----
  function toggleSolution(btn) {
    btn.classList.toggle('solution-toggle--open');
    const content = btn.nextElementSibling;
    content.classList.toggle('solution-content--visible');
    btn.innerHTML = content.classList.contains('solution-content--visible')
      ? '<span class="solution-toggle__arrow">▶</span> Hide Solution'
      : '<span class="solution-toggle__arrow">▶</span> Show Solution';
    KatexRender.render(content);
  }

  function toggleHint(btn) {
    btn.classList.toggle('solution-toggle--open');
    const content = btn.nextElementSibling;
    content.classList.toggle('hint-content--visible');
    KatexRender.render(content);
  }

  // ---- Sort handler ----
  function sort(key) {
    if (currentSort.key === key) {
      currentSort.dir = currentSort.dir === 'asc' ? 'desc' : 'asc';
    } else {
      currentSort = { key, dir: 'asc' };
    }
    renderList(App.getParams());
  }

  // ---- Format helpers ----
  function formatTag(id) {
    return id.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
  }

  function formatType(t) {
    const map = {
      'closed-form': 'Closed-Form',
      'proof': 'Proof',
      'coding': 'Coding',
      'open-ended': 'Open-Ended',
      'brain-teaser': 'Brain Teaser',
      'estimation': 'Estimation',
      'math': 'Closed-Form',
      'logic': 'Brain Teaser',
    };
    return map[t] || t;
  }

  return { init, toggleSolution, toggleHint, filterCat, filterDiff, filterType, sort };
})();
