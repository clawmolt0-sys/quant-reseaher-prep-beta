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
    'bridgewater':    'https://upload.wikimedia.org/wikipedia/commons/2/2c/Bridgewater_Associates_logo.svg',
    'imc-trading':    'https://upload.wikimedia.org/wikipedia/commons/3/31/IMC_logo.svg',
    'flow-traders':   'https://upload.wikimedia.org/wikipedia/commons/6/62/Flow_Traders_logo.svg',
    'virtu-financial': 'https://upload.wikimedia.org/wikipedia/commons/7/7e/Virtu_Financial_logo.svg',
    'man-group':      'https://upload.wikimedia.org/wikipedia/commons/0/03/Man_Group_logo.svg',
    'wolverine-trading': 'https://upload.wikimedia.org/wikipedia/commons/7/76/Wolverine_Trading_Logo.svg',
    'akuna-capital':  'https://upload.wikimedia.org/wikipedia/commons/b/ba/Akuna_Capital_logo.svg',
    'worldquant':     'https://upload.wikimedia.org/wikipedia/commons/9/9a/WorldQuant_Logo.svg',
    'balyasny':       'https://upload.wikimedia.org/wikipedia/commons/6/63/Balyasny_Asset_Management_logo.svg',
    'xtx-markets':    'https://upload.wikimedia.org/wikipedia/commons/8/8b/XTX_Markets_logo.svg',
  };

  // Company accent colors
  const COMPANY_COLORS = {
    'citadel':          '#4c8bf5',
    'two-sigma':        '#00a3e0',
    'de-shaw':          '#1a3a5c',
    'jump-trading':     '#e74c3c',
    'drw':              '#f5b731',
    'hrt':              '#2dd4bf',
    'jane-street':      '#22c55e',
    'optiver':          '#ff6b35',
    'sig':              '#8b5cf6',
    'squarepoint':      '#a78bfa',
    'tower-research':   '#f472b6',
    'millennium':       '#06b6d4',
    'point72':          '#64748b',
    'aqr':              '#0ea5e9',
    'renaissance':      '#f59e0b',
    'five-rings':       '#ef4444',
    // New major firms
    'bridgewater':      '#1e3a5f',
    'imc-trading':      '#00529b',
    'flow-traders':     '#0066cc',
    'virtu-financial':  '#003366',
    'man-group':        '#dc3545',
    'g-research':       '#6366f1',
    'wolverine-trading':'#b91c1c',
    'akuna-capital':    '#059669',
    'belvedere-trading':'#d946ef',
    'worldquant':       '#7c3aed',
    'old-mission-capital':'#0d9488',
    'transmarket':      '#ca8a04',
    'balyasny':         '#334155',
    'schonfeld':        '#475569',
    'xtx-markets':      '#7c3aed',
    'qube-research':    '#2563eb',
    'marshall-wace':    '#1e40af',
    'tudor':            '#92400e',
    'pdt-partners':     '#065f46',
    'radix-trading':    '#b45309',
    'brevan-howard':    '#1f2937',
    'elliott-management':'#374151',
    'capstone':         '#6b7280',
    'walleye-capital':  '#0284c7',
    'winton-group':     '#16a34a',
    'voleon-group':     '#9333ea',
    'voloridge':        '#4f46e5',
    'rokos-capital':    '#be123c',
    'peak6':            '#ea580c',
    'gts':              '#0369a1',
    'headlands-technologies': '#15803d',
    'quantlab':         '#c026d3',
    'allston-trading':  '#e11d48',
    'hudson-bay':       '#0891b2',
    'gelber-group':     '#d97706',
    'chicago-trading':  '#991b1b',
    'group-one-trading':'#7e22ce',
    'simplex-trading':  '#db2777',
    'maven-securities': '#059669',
    'gsa-capital':      '#2563eb',
    'tradebot-systems': '#dc2626',
    'goldman-sachs':    '#003A70',
    'hft':              '#94a3b8',
  };

  async function init() {
    const container = document.getElementById('explore-content');
    if (!container) return;

    // Show Coming Soon page
    container.innerHTML = `
      <div class="container" style="max-width:800px">
        <div class="coming-soon-hero">
          <div class="coming-soon-hero__icon">
            <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
              <line x1="11" y1="8" x2="11" y2="14"/><line x1="8" y1="11" x2="14" y2="11"/>
            </svg>
          </div>
          <h1 class="coming-soon-hero__title">Explore</h1>
          <p class="coming-soon-hero__subtitle">Curated problem lists, topic deep-dives, and company-specific prep — all in one place.</p>
          <div class="coming-soon-hero__badge">\u{1F6A7} Coming Soon</div>
          <p class="coming-soon-hero__desc">
            We\u2019re hand-picking the best problem collections and building curated tracks for each major quant firm.
            This section will include featured lists, topic explorations, and company-specific problem sets.
          </p>
          <div class="coming-soon-hero__preview">
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F3C6}</div>
              <div class="coming-soon-card__text">Curated Lists</div>
            </div>
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F4CA}</div>
              <div class="coming-soon-card__text">Topic Deep-Dives</div>
            </div>
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F3E2}</div>
              <div class="coming-soon-card__text">Company Prep</div>
            </div>
          </div>
          <a href="problems.html" class="btn btn--primary" style="margin-top:var(--space-6)">Browse All Problems \u2192</a>
        </div>
      </div>
    `;
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

    // Filter out companies with zero problems, then sort by count (descending)
    const sorted = [...companies]
      .filter(c => counts[c.id] && counts[c.id] > 0)
      .sort((a, b) => (counts[b.id] || 0) - (counts[a.id] || 0));

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
