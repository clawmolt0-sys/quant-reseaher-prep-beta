/* ============================================
   EXPLORE — Curated lists, topic & company cards
   ============================================ */

const Explore = (() => {
  // Icon map for featured list and topic cards
  const ICON_MAP = {
    'trophy':    '\uD83C\uDFC6',
    'star':      '\u2B50',
    'code':      '\uD83D\uDCBB',
    'book':      '\uD83D\uDCD7',
    'dice':      '\uD83C\uDFB2',
    'game':      '\uD83C\uDFAF',
    'chart':     '\uD83D\uDCC8',
    'puzzle':    '\uD83E\uDDE9',
    'trending':  '\uD83D\uDCC8',
    'math':      '\u222B',
    'bar-chart': '\uD83D\uDCCA',
  };

  // Company logo URLs (reused from index.html)
  const COMPANY_LOGOS = {
    'citadel':        'https://upload.wikimedia.org/wikipedia/commons/4/45/Citadel_LLC_Logo.svg',
    'two-sigma':      'https://upload.wikimedia.org/wikipedia/commons/c/c6/Two_Sigma_logo.svg',
    'de-shaw':        'https://upload.wikimedia.org/wikipedia/commons/6/62/D._E._Shaw_%26_Co._Logo.svg',
    'jump-trading':   'https://upload.wikimedia.org/wikipedia/commons/b/bd/Jump_Trading_logo.svg',
    'hrt':            'https://upload.wikimedia.org/wikipedia/commons/a/aa/Hudson_River_Trading_Logo.svg',
    'jane-street':    'https://upload.wikimedia.org/wikipedia/commons/c/c9/Jane_Street_Capital_Logo.svg',
    'optiver':        'https://upload.wikimedia.org/wikipedia/commons/3/36/Optiver_Logo.svg',
    'squarepoint':    'https://upload.wikimedia.org/wikipedia/commons/7/7c/Squarepoint_Capital.svg',
    'millennium':     'https://upload.wikimedia.org/wikipedia/commons/6/60/Millennium_logo.svg',
    'point72':        'https://upload.wikimedia.org/wikipedia/commons/f/f9/Point72logo.png',
    'renaissance':    'https://upload.wikimedia.org/wikipedia/commons/0/0f/Renaissance_Technologies.png',
  };

  // Company accent colors
  const COMPANY_COLORS = {
    'citadel':        '#4c8bf5',
    'two-sigma':      '#00a3e0',
    'de-shaw':        '#1a3a5c',
    'jump-trading':   '#e74c3c',
    'drw':            '#f5b731',
    'hrt':            '#2dd4bf',
    'jane-street':    '#22c55e',
    'optiver':        '#ff6b35',
    'sig':            '#8b5cf6',
    'squarepoint':    '#a78bfa',
    'tower-research': '#f472b6',
    'millennium':     '#06b6d4',
    'point72':        '#64748b',
    'aqr':            '#0ea5e9',
    'renaissance':    '#f59e0b',
    'five-rings':     '#ef4444',
  };

  async function init() {
    const [problems, companies, featuredData] = await Promise.all([
      DataLoader.problems(),
      DataLoader.companies(),
      DataLoader.featuredLists(),
    ]);

    if (!problems || !companies || !featuredData) {
      document.getElementById('explore-content').innerHTML = `
        <div class="container"><div class="empty-state">
          <div class="empty-state__icon">\u26A0\uFE0F</div>
          <div class="empty-state__title">Failed to load data</div>
        </div></div>`;
      return;
    }

    render(problems, companies, featuredData);
  }

  function render(problems, companies, featuredData) {
    const container = document.getElementById('explore-content');
    if (!container) return;

    const featured = featuredData.featured || [];
    const topicLists = featuredData.topicLists || [];

    container.innerHTML = `
      <div class="container" style="max-width:1000px">
        ${renderFeaturedSection(featured, problems)}
        ${renderTopicSection(topicLists, problems)}
        ${renderCompanySection(companies, problems)}
      </div>
    `;
  }

  // ---- Featured Lists ----
  function renderFeaturedSection(lists, problems) {
    const cards = lists.map(list => {
      const count = list.problemIds ? list.problemIds.length : 0;
      const icon = ICON_MAP[list.icon] || '\uD83D\uDCCB';
      const color = list.color || '#4c8bf5';

      return `
        <a class="featured-card" href="problems.html?list=${list.id}" style="--accent-color:${color}">
          <span style="position:absolute;top:0;left:0;width:4px;height:100%;background:${color};border-radius:4px 0 0 4px"></span>
          <div class="featured-card__icon" style="background:${color}15;color:${color}">${icon}</div>
          <div class="featured-card__body">
            <div class="featured-card__title">${list.title}</div>
            <div class="featured-card__desc">${list.description}</div>
            <span class="featured-card__count">${count} problems</span>
          </div>
        </a>
      `;
    }).join('');

    return `
      <section class="explore-section">
        <div class="explore-section__label">Featured</div>
        <h2 class="explore-section__title">Curated Problem Lists</h2>
        <p class="explore-section__desc">Hand-picked collections to fast-track your interview preparation.</p>
        <div class="featured-grid">${cards}</div>
      </section>
    `;
  }

  // ---- Topic Exploration ----
  function renderTopicSection(topicLists, problems) {
    const cards = topicLists.map(topic => {
      const count = countByFilter(problems, topic.filter);
      const icon = ICON_MAP[topic.icon] || '\uD83D\uDCCB';
      const color = topic.color || '#4c8bf5';
      const href = buildFilterURL(topic.filter);

      return `
        <a class="topic-card" href="${href}">
          <div class="topic-card__icon" style="background:${color}15;color:${color}">${icon}</div>
          <div class="topic-card__title">${topic.title}</div>
          <div class="topic-card__desc">${topic.description}</div>
          <div class="topic-card__count">${count} problems</div>
        </a>
      `;
    }).join('');

    return `
      <section class="explore-section">
        <div class="explore-section__label">Browse by Topic</div>
        <h2 class="explore-section__title">Explore by Subject</h2>
        <p class="explore-section__desc">Dive deep into specific areas tested in quant interviews.</p>
        <div class="topic-grid">${cards}</div>
      </section>
    `;
  }

  // ---- Company Grid ----
  function renderCompanySection(companies, problems) {
    // Count problems per company
    const counts = {};
    problems.forEach(p => {
      const comps = p.companies || p.company || [];
      const arr = Array.isArray(comps) ? comps : [comps];
      arr.forEach(c => { counts[c] = (counts[c] || 0) + 1; });
    });

    // Sort by problem count (descending)
    const sorted = [...companies].sort((a, b) => (counts[b.id] || 0) - (counts[a.id] || 0));

    const cards = sorted.map(c => {
      const count = counts[c.id] || 0;
      const color = COMPANY_COLORS[c.id] || '#4c8bf5';
      const logo = COMPANY_LOGOS[c.id];
      const typeLabel = c.type || '';

      const logoHTML = logo
        ? `<img class="company-card__logo" src="${logo}" alt="${c.name}" onerror="this.outerHTML='<span class=\\'company-card__logo--text\\'>${c.name.substring(0, 3)}</span>'">`
        : `<span class="company-card__logo--text">${c.name.substring(0, 3)}</span>`;

      return `
        <a class="company-card" href="problems.html?company=${c.id}">
          <span style="position:absolute;top:0;left:0;width:3px;height:100%;background:${color}"></span>
          ${logoHTML}
          <div class="company-card__info">
            <div class="company-card__name">${c.name}</div>
            <div class="company-card__meta">
              ${typeLabel ? `<span class="company-card__type">${typeLabel}</span>` : ''}
              <span class="company-card__count">${count} problems</span>
            </div>
          </div>
        </a>
      `;
    }).join('');

    return `
      <section class="explore-section">
        <div class="explore-section__label">Browse by Firm</div>
        <h2 class="explore-section__title">Explore by Company</h2>
        <p class="explore-section__desc">Practice problems from specific firms to target your preparation.</p>
        <div class="company-grid">${cards}</div>
      </section>
    `;
  }

  // ---- Helpers ----
  function countByFilter(problems, filter) {
    if (!filter) return 0;
    return problems.filter(p => {
      for (const [key, value] of Object.entries(filter)) {
        if (key === 'category') {
          if (p.category !== value && !(p.topics || []).includes(value)) return false;
        } else if (key === 'type') {
          if (p.type !== value) return false;
        } else if (key === 'tags') {
          if (!(p.tags || []).includes(value)) return false;
        } else if (key === 'subtopics') {
          if (!(p.subtopics || []).includes(value)) return false;
        }
      }
      return true;
    }).length;
  }

  function buildFilterURL(filter) {
    if (!filter) return 'problems.html';
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(filter)) {
      if (key === 'category') params.set('topic', value);
      else if (key === 'type') params.set('type', value);
      else if (key === 'tags') params.set('tag', value);
      else if (key === 'subtopics') params.set('subtopic', value);
    }
    return 'problems.html?' + params.toString();
  }

  return { init };
})();
