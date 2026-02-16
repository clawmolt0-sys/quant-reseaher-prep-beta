/* ============================================
   PROBLEMS — Problem list + detail rendering
   ============================================ */

const Problems = (() => {
  let allProblems = [];
  let topicsData = null;
  let companiesData = null;

  async function init() {
    allProblems = (await DataLoader.problems()) || [];
    topicsData = (await DataLoader.topics()) || { tracks: [] };
    companiesData = (await DataLoader.companies()) || [];

    const params = App.getParams();

    if (params.id) {
      renderDetail(params.id);
    } else {
      renderList(params);
    }
  }

  // ---- List View ----
  function renderList(params) {
    const container = document.getElementById('content');
    if (!container) return;

    // Build filter options
    const allTopics = [];
    topicsData.tracks.forEach(track => {
      track.topics.forEach(t => allTopics.push(t));
    });
    const allCompanies = companiesData;

    // Filter problems
    let filtered = [...allProblems];
    if (params.topic) {
      filtered = filtered.filter(p => p.topics.includes(params.topic));
    }
    if (params.company) {
      filtered = filtered.filter(p => p.company.includes(params.company));
    }
    if (params.difficulty) {
      filtered = filtered.filter(p => p.difficulty === params.difficulty);
    }
    if (params.q) {
      const q = params.q.toLowerCase();
      filtered = filtered.filter(p =>
        p.title.toLowerCase().includes(q) ||
        p.statement.toLowerCase().includes(q)
      );
    }

    const activeTopicTitle = params.topic
      ? allTopics.find(t => t.id === params.topic)?.title || params.topic
      : null;
    const activeCompanyName = params.company
      ? allCompanies.find(c => c.id === params.company)?.name || params.company
      : null;

    let headerText = 'All Problems';
    if (activeTopicTitle && activeCompanyName) {
      headerText = `${activeCompanyName} — ${activeTopicTitle}`;
    } else if (activeTopicTitle) {
      headerText = activeTopicTitle;
    } else if (activeCompanyName) {
      headerText = activeCompanyName;
    }

    container.innerHTML = `
      <div class="container">
        <div class="section-header">
          <h1 class="section-header__title">${headerText}</h1>
          <p class="section-header__subtitle">Practice problems from top quant firms. Click to reveal solutions.</p>
        </div>

        <div class="filter-bar">
          <input type="text" class="filter-bar__search" id="search"
            placeholder="Search problems..." value="${params.q || ''}">

          <select class="filter-bar__select" id="filter-topic">
            <option value="">All Topics</option>
            ${allTopics.map(t =>
              `<option value="${t.id}" ${params.topic === t.id ? 'selected' : ''}>${t.title}</option>`
            ).join('')}
          </select>

          <select class="filter-bar__select" id="filter-company">
            <option value="">All Companies</option>
            ${allCompanies.map(c =>
              `<option value="${c.id}" ${params.company === c.id ? 'selected' : ''}>${c.name}</option>`
            ).join('')}
          </select>

          <select class="filter-bar__select" id="filter-difficulty">
            <option value="">All Difficulties</option>
            <option value="easy" ${params.difficulty === 'easy' ? 'selected' : ''}>Easy</option>
            <option value="medium" ${params.difficulty === 'medium' ? 'selected' : ''}>Medium</option>
            <option value="hard" ${params.difficulty === 'hard' ? 'selected' : ''}>Hard</option>
          </select>
        </div>

        <p class="problem-count">${filtered.length} problem${filtered.length !== 1 ? 's' : ''}</p>

        <div class="problem-list" id="problem-list">
          ${filtered.map((p, i) => problemCard(p, i + 1)).join('')}
        </div>

        ${filtered.length === 0 ? `
          <div class="empty-state">
            <div class="empty-state__icon">🔍</div>
            <div class="empty-state__title">No problems found</div>
            <p>Try adjusting your filters.</p>
          </div>
        ` : ''}
      </div>
    `;

    // Bind filter events
    const applyFilters = () => {
      const newParams = {
        q: document.getElementById('search').value || null,
        topic: document.getElementById('filter-topic').value || null,
        company: document.getElementById('filter-company').value || null,
        difficulty: document.getElementById('filter-difficulty').value || null,
      };
      App.setParams(newParams);
      renderList(newParams);
      KatexRender.render(container);
    };

    document.getElementById('filter-topic').addEventListener('change', applyFilters);
    document.getElementById('filter-company').addEventListener('change', applyFilters);
    document.getElementById('filter-difficulty').addEventListener('change', applyFilters);

    let searchTimeout;
    document.getElementById('search').addEventListener('input', () => {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(applyFilters, 300);
    });

    KatexRender.render(container);
  }

  function problemCard(problem, index) {
    const topicTags = problem.topics.slice(0, 2).map(t =>
      `<span class="tag tag--topic">${formatTopicName(t)}</span>`
    ).join('');

    const companyTags = problem.company.slice(0, 2).map(c =>
      `<span class="tag tag--company">${formatCompanyName(c)}</span>`
    ).join('');

    return `
      <a class="problem-card" href="problems.html?id=${problem.id}">
        <span class="problem-card__number">${index}</span>
        <span class="problem-card__title">${App.escapeHtml(problem.title)}</span>
        <span class="problem-card__tags">
          ${App.difficultyBadge(problem.difficulty)}
          ${topicTags}
          ${companyTags}
        </span>
      </a>
    `;
  }

  // ---- Detail View ----
  function renderDetail(id) {
    const container = document.getElementById('content');
    if (!container) return;

    const problem = allProblems.find(p => p.id === id);
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

    const topicTags = problem.topics.map(t =>
      `<a class="tag tag--topic" href="problems.html?topic=${t}">${formatTopicName(t)}</a>`
    ).join('');

    const companyTags = problem.company.map(c =>
      `<a class="tag tag--company" href="problems.html?company=${c}">${formatCompanyName(c)}</a>`
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
          <span>${App.escapeHtml(problem.title)}</span>
        </div>

        <div class="problem-detail">
          <div class="problem-detail__header">
            <h1 class="problem-detail__title">${App.escapeHtml(problem.title)}</h1>
            <div class="problem-detail__meta">
              ${App.difficultyBadge(problem.difficulty)}
              ${topicTags}
              ${companyTags}
              <span class="tag">${problem.type}</span>
            </div>
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
              ? `<a class="problem-nav-btn" href="problems.html?id=${prev.id}">← ${App.escapeHtml(prev.title)}</a>`
              : '<span></span>'
            }
            ${next
              ? `<a class="problem-nav-btn" href="problems.html?id=${next.id}">${App.escapeHtml(next.title)} →</a>`
              : '<span></span>'
            }
          </div>
        </div>
      </div>
    `;

    KatexRender.render(container);
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

  // ---- Helpers ----
  function formatTopicName(id) {
    return id.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
  }

  function formatCompanyName(id) {
    const nameMap = {
      'citadel': 'Citadel',
      'two-sigma': 'Two Sigma',
      'de-shaw': 'D.E. Shaw',
      'jump-trading': 'Jump Trading',
      'drw': 'DRW',
      'hrt': 'HRT',
      'jane-street': 'Jane Street',
      'optiver': 'Optiver',
      'sig': 'SIG',
      'squarepoint': 'Squarepoint',
      'tower-research': 'Tower Research',
      'millennium': 'Millennium',
      'point72': 'Point72',
      'aqr': 'AQR',
      'renaissance': 'Renaissance',
      'five-rings': 'Five Rings',
      'hft': 'HFT Firm',
    };
    return nameMap[id] || id;
  }

  return { init, toggleSolution, toggleHint };
})();
