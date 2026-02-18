/* ============================================
   PROFILE — Full LeetCode-style profile page
   Activity heatmap, karma, badges, stats
   ============================================ */

const Profile = (() => {

  let profileProblems = null; // cached normalized problems for re-renders
  let profileProblemMap = null; // Map<id, problem> for O(1) lookups

  async function init() {
    const container = document.getElementById('profile-content');
    if (!container) return;

    // Show skeleton loading state immediately
    container.innerHTML = renderSkeleton();

    // Start loading problems INDEX + auth in PARALLEL (don't wait for one before the other)
    const dataPromise = DataLoader.problemsIndex();
    const authPromise = Promise.race([
      Auth.waitForAuth(),
      new Promise(resolve => setTimeout(resolve, 1500)) // 1.5s max, not 2s
    ]);

    // Wait for both to settle
    const [rawProblems] = await Promise.all([dataPromise, authPromise]);

    // Normalize index data once and cache
    profileProblems = (rawProblems || []).map(p => ({
      id: p.id,
      title: p.t || p.title || '',
      category: p.c || p.category || 'probability',
      difficulty: p.d || p.difficulty || 'medium',
      type: p.y || p.type || 'calculation',
      status: p.s || p.status || 'complete',
      companies: p.co || p.companies || [],
      tags: p.tg || p.tags || [],
    }));
    // Build Map for O(1) lookups
    profileProblemMap = new Map();
    for (const p of profileProblems) profileProblemMap.set(p.id, p);

    if (!Auth.isLoggedIn()) {
      container.innerHTML = `
        <div class="container" style="max-width:600px;text-align:center;padding:var(--space-12) var(--space-4)">
          <div style="font-size:3rem;margin-bottom:var(--space-4)">\uD83D\uDD12</div>
          <h2 style="margin-bottom:var(--space-3)">Sign In to View Profile</h2>
          <p style="color:var(--text-secondary);margin-bottom:var(--space-6)">Track your progress, earn achievements, and build your quant interview reputation.</p>
          <button class="btn btn--primary" onclick="Auth.showAuthModal()">Sign In</button>
        </div>`;

      // Listen for sign-in after page load
      window.addEventListener('auth-state-changed', () => {
        if (Auth.isLoggedIn()) renderProfile();
      });
      return;
    }

    renderProfile();

    // Re-render when auth data updates (e.g. Firestore doc finishes loading late)
    window.addEventListener('auth-state-changed', () => {
      if (!Auth.isLoggedIn()) {
        init();
        return;
      }
      renderProfile();
    });

    // Re-render when user marks a problem as solved/attempted (fires from saveStatus)
    window.addEventListener('user-data-changed', () => {
      if (Auth.isLoggedIn()) renderProfile();
    });
  }

  function renderProfile() {
    const user = Auth.getUser();
    let userDoc = Auth.getUserDoc();
    const problems = profileProblems;
    const container = document.getElementById('profile-content');

    if (!user || !problems || !container) return;

    // If userDoc has no progress, try loading from localStorage cache
    if (!userDoc || (Object.keys(userDoc.progress || {}).length === 0)) {
      try {
        const cached = JSON.parse(localStorage.getItem('qr-prep-userDoc-cache') || 'null');
        if (cached && Object.keys(cached.progress || {}).length > 0) {
          console.log('[Profile] Using cached userDoc from localStorage (' + Object.keys(cached.progress).length + ' progress entries)');
          // Merge cached data into userDoc
          if (!userDoc) {
            userDoc = cached;
          } else {
            userDoc.progress = cached.progress || userDoc.progress || {};
            userDoc.stats = cached.stats || userDoc.stats || {};
            userDoc.xp = cached.xp || userDoc.xp || 0;
            userDoc.level = cached.level || userDoc.level || 1;
            userDoc.streak = cached.streak || userDoc.streak || { current: 0, longest: 0 };
            userDoc.favorites = cached.favorites || userDoc.favorites || [];
            userDoc.collections = cached.collections || userDoc.collections || [];
            userDoc.achievements = cached.achievements || userDoc.achievements || [];
          }
        }
      } catch (e) { /* ignore parse errors */ }
    }

    // Use userDoc or a sensible default if nothing available
    const doc = userDoc || {
      progress: {}, stats: { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } },
      xp: 0, level: 1, streak: { current: 0, longest: 0 }, favorites: [], collections: [], achievements: []
    };

    // If stats are all zero but we have progress data, recalculate from progress
    const stats = doc.stats || {};
    const totalFromStats = (stats.easy?.solved || 0) + (stats.medium?.solved || 0) + (stats.hard?.solved || 0);
    if (totalFromStats === 0 && doc.progress && Object.keys(doc.progress).length > 0) {
      console.log('[Profile] Stats are 0 but progress exists, recalculating...');
      recalculateStats(doc, problems);

      // Persist recalculated stats to Firestore if available
      try {
        const db = FirebaseConfig.getDb();
        const currentUser = Auth.getUser();
        if (db && currentUser && Auth.isFirestoreAvailable()) {
          db.collection('users').doc(currentUser.uid).update({
            stats: doc.stats, xp: doc.xp, level: doc.level
          }).then(() => console.log('[Profile] Recalculated stats saved to Firestore'))
            .catch(err => console.warn('[Profile] Could not save recalculated stats:', err));
        }
      } catch (e) { /* ignore */ }
    }

    render(user, doc, problems, []);
  }

  // Recalculate stats from progress data (fixes stale/empty stats)
  function recalculateStats(doc, problems) {
    const progress = doc.progress || {};
    const stats = { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } };
    let xp = 0;
    const XP_TABLE = { easy: 10, medium: 25, hard: 50 };
    const problemMap = new Map();
    for (const p of problems) problemMap.set(p.id, p);

    for (const [idStr, status] of Object.entries(progress)) {
      const p = problemMap.get(parseInt(idStr));
      const diff = p ? p.difficulty : 'medium';
      if (!stats[diff]) stats[diff] = { solved: 0, attempted: 0 };
      if (status === 'solved') {
        stats[diff].solved++;
        xp += XP_TABLE[diff] || 0;
      } else if (status === 'attempted') {
        stats[diff].attempted++;
      }
    }

    doc.stats = stats;
    if (!doc.xp || doc.xp === 0) doc.xp = xp;
    if (!doc.level || doc.level <= 1) {
      doc.level = Auth.calculateLevel(doc.xp).level;
    }
  }

  // ---- Skeleton Loading State ----
  function renderSkeleton() {
    const shimmer = 'background:linear-gradient(90deg,var(--bg-card) 25%,var(--border-color) 50%,var(--bg-card) 75%);background-size:200% 100%;animation:shimmer 1.5s ease-in-out infinite';
    return `
      <style>@keyframes shimmer{0%{background-position:200% 0}100%{background-position:-200% 0}}</style>
      <div class="container" style="max-width:1000px">
        <div class="profile-header">
          <div class="profile-header__left">
            <div style="width:80px;height:80px;border-radius:50%;${shimmer}"></div>
            <div class="profile-header__info">
              <div style="width:180px;height:24px;border-radius:6px;margin-bottom:10px;${shimmer}"></div>
              <div style="width:100px;height:14px;border-radius:4px;margin-bottom:6px;${shimmer}"></div>
              <div style="width:130px;height:12px;border-radius:4px;${shimmer}"></div>
            </div>
          </div>
        </div>
        <div class="profile-stats-grid">
          <div class="profile-card" style="min-height:180px">
            <div style="width:140px;height:16px;border-radius:4px;margin-bottom:16px;${shimmer}"></div>
            <div style="display:flex;gap:24px;align-items:center">
              <div style="width:120px;height:120px;border-radius:50%;${shimmer}"></div>
              <div style="flex:1">
                <div style="height:12px;border-radius:4px;margin-bottom:12px;${shimmer}"></div>
                <div style="height:12px;border-radius:4px;margin-bottom:12px;${shimmer}"></div>
                <div style="height:12px;border-radius:4px;${shimmer}"></div>
              </div>
            </div>
          </div>
          <div class="profile-card" style="min-height:180px">
            <div style="width:100px;height:16px;border-radius:4px;margin-bottom:16px;${shimmer}"></div>
            <div style="display:flex;flex-wrap:wrap;gap:12px">
              <div style="width:80px;height:70px;border-radius:8px;${shimmer}"></div>
              <div style="width:80px;height:70px;border-radius:8px;${shimmer}"></div>
              <div style="width:80px;height:70px;border-radius:8px;${shimmer}"></div>
              <div style="width:80px;height:70px;border-radius:8px;${shimmer}"></div>
            </div>
          </div>
        </div>
        <div class="profile-card profile-card--wide" style="min-height:120px">
          <div style="width:200px;height:16px;border-radius:4px;margin-bottom:16px;${shimmer}"></div>
          <div style="height:80px;border-radius:4px;${shimmer}"></div>
        </div>
      </div>
    `;
  }

  function render(user, userDoc, problems, companies) {
    const container = document.getElementById('profile-content');
    if (!container) return;

    const progress = userDoc.progress || {};
    const stats = userDoc.stats || { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } };
    const xp = userDoc.xp || 0;
    const levelInfo = Auth.calculateLevel(xp);
    const streak = userDoc.streak || { current: 0, longest: 0 };
    const favorites = userDoc.favorites || [];
    const tier = Auth.getTier();

    const joinDate = userDoc.joinDate
      ? (userDoc.joinDate.toDate ? userDoc.joinDate.toDate() : new Date(userDoc.joinDate))
      : new Date();
    const joinDateStr = joinDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

    // Counts
    const totalSolved = (stats.easy?.solved || 0) + (stats.medium?.solved || 0) + (stats.hard?.solved || 0);
    const totalAttempted = (stats.easy?.attempted || 0) + (stats.medium?.attempted || 0) + (stats.hard?.attempted || 0);
    const totalProblems = problems.length;
    const totalEasy = problems.filter(p => p.difficulty === 'easy').length;
    const totalMedium = problems.filter(p => p.difficulty === 'medium').length;
    const totalHard = problems.filter(p => p.difficulty === 'hard').length;

    // Karma calculation
    const karma = calculateKarma(userDoc, totalSolved);

    // Skills breakdown
    const skills = calculateSkills(userDoc, problems);

    // Recent solved
    const recentSolved = getRecentSolved(userDoc, problems);

    // Activity heatmap data
    const heatmapData = buildHeatmapData(userDoc);

    container.innerHTML = `
      <div class="container" style="max-width:1000px">
        <!-- Profile Header -->
        <div class="profile-header">
          <div class="profile-header__left">
            ${user.photoURL
              ? `<img class="profile-header__avatar" src="${user.photoURL}" alt="" referrerpolicy="no-referrer">`
              : `<span class="profile-header__avatar profile-header__avatar--initials">${(user.displayName || 'U').charAt(0)}</span>`
            }
            <div class="profile-header__info">
              <h1 class="profile-header__name">${user.displayName || 'User'}</h1>
              <div class="profile-header__meta">
                <span class="tier-badge tier-badge--${tier}">${tier === 'pro' ? 'Pro' : 'Free'}</span>
                <span class="profile-header__rank">Rank #${Math.max(1, Math.floor(10000 / Math.max(1, totalSolved)))}</span>
              </div>
              <div class="profile-header__joined">Joined ${joinDateStr}</div>
            </div>
          </div>
          <div class="profile-header__right">
            <a href="problems.html" class="btn btn--primary btn--sm">Practice Now</a>
          </div>
        </div>

        <!-- Stats Grid -->
        <div class="profile-stats-grid">
          <!-- Solved Card with Ring -->
          <div class="profile-card profile-card--solved">
            <div class="profile-card__header">Solved Problems</div>
            <div class="solved-overview">
              <div class="solved-ring">
                ${buildSolvedRing(totalSolved, totalProblems)}
              </div>
              <div class="solved-breakdown">
                <div class="solved-row">
                  <span class="solved-row__label">Easy</span>
                  <span class="solved-row__count">${stats.easy?.solved || 0}<span class="solved-row__total">/${totalEasy}</span></span>
                  <div class="solved-row__bar"><div class="solved-row__fill solved-row__fill--easy" style="width:${totalEasy > 0 ? ((stats.easy?.solved || 0)/totalEasy*100) : 0}%"></div></div>
                </div>
                <div class="solved-row">
                  <span class="solved-row__label">Medium</span>
                  <span class="solved-row__count">${stats.medium?.solved || 0}<span class="solved-row__total">/${totalMedium}</span></span>
                  <div class="solved-row__bar"><div class="solved-row__fill solved-row__fill--medium" style="width:${totalMedium > 0 ? ((stats.medium?.solved || 0)/totalMedium*100) : 0}%"></div></div>
                </div>
                <div class="solved-row">
                  <span class="solved-row__label">Hard</span>
                  <span class="solved-row__count">${stats.hard?.solved || 0}<span class="solved-row__total">/${totalHard}</span></span>
                  <div class="solved-row__bar"><div class="solved-row__fill solved-row__fill--hard" style="width:${totalHard > 0 ? ((stats.hard?.solved || 0)/totalHard*100) : 0}%"></div></div>
                </div>
              </div>
            </div>
          </div>

          <!-- Badges Card -->
          <div class="profile-card">
            <div class="profile-card__header">Badges</div>
            ${renderBadgesCard(userDoc)}
          </div>
        </div>

        <!-- Activity Heatmap -->
        <div class="profile-card profile-card--wide">
          <div class="profile-card__header">
            <span>${totalSolved} problems solved in the past year</span>
          </div>
          <div class="heatmap-container">
            ${renderHeatmap(heatmapData)}
          </div>
        </div>

        <!-- Community Stats -->
        <div class="profile-community">
          <div class="profile-card">
            <div class="profile-card__header">Community Stats</div>
            <div class="community-stats">
              <div class="community-stat">
                <div class="community-stat__icon">\uD83D\uDC41\uFE0F</div>
                <div class="community-stat__value">${Math.floor(totalSolved * 12.5)}</div>
                <div class="community-stat__label">Views</div>
              </div>
              <div class="community-stat">
                <div class="community-stat__icon">\u2705</div>
                <div class="community-stat__value">${totalSolved}</div>
                <div class="community-stat__label">Solutions</div>
              </div>
              <div class="community-stat">
                <div class="community-stat__icon">\uD83D\uDCAC</div>
                <div class="community-stat__value">0</div>
                <div class="community-stat__label">Discuss</div>
              </div>
              <div class="community-stat">
                <div class="community-stat__icon">\u2B50</div>
                <div class="community-stat__value">${karma}</div>
                <div class="community-stat__label">Reputation</div>
              </div>
            </div>
          </div>

          <!-- Level & XP -->
          <div class="profile-card">
            <div class="profile-card__header">Level & XP</div>
            <div class="profile-level-detail">
              <div class="profile-level-detail__badge">Level ${levelInfo.level}</div>
              <div class="profile-level-detail__xp">${xp} XP total</div>
              <div class="profile-level-detail__bar">
                <div class="profile-level-detail__fill" style="width:${levelInfo.percent}%"></div>
              </div>
              <div class="profile-level-detail__text">${levelInfo.currentXP} / ${levelInfo.nextLevelXP} XP to next level</div>
            </div>
            <div class="profile-streak-row">
              <div class="profile-streak-item">
                <span class="profile-streak-item__icon">\uD83D\uDD25</span>
                <span class="profile-streak-item__value">${streak.current || 0}</span>
                <span class="profile-streak-item__label">Current Streak</span>
              </div>
              <div class="profile-streak-item">
                <span class="profile-streak-item__icon">\uD83C\uDFC6</span>
                <span class="profile-streak-item__value">${streak.longest || 0}</span>
                <span class="profile-streak-item__label">Best Streak</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Skills -->
        <div class="profile-card profile-card--wide">
          <div class="profile-card__header">Skills</div>
          ${renderSkills(skills)}
        </div>

        <!-- Tabs: Solved, Attempted, Favorites, Collections -->
        <div class="profile-card profile-card--wide">
          <div class="profile-tabs">
            <button class="profile-tab profile-tab--active" onclick="Profile.switchTab('recent')">Solved (${totalSolved})</button>
            <button class="profile-tab" onclick="Profile.switchTab('attempted')">Attempted (${totalAttempted})</button>
            <button class="profile-tab" onclick="Profile.switchTab('favorites')">Favorites (${favorites.length})</button>
            <button class="profile-tab" onclick="Profile.switchTab('collections')">Saved Lists (${(userDoc.collections || []).length})</button>
          </div>
          <div id="profile-tab-content">
            ${renderRecentTab(recentSolved)}
          </div>
        </div>
      </div>
    `;
  }

  // ---- Karma Calculation ----
  function calculateKarma(userDoc, totalSolved) {
    let karma = 0;
    karma += totalSolved * 10;                              // 10 karma per solve
    karma += (userDoc.xp || 0);                             // XP contributes to karma
    karma += ((userDoc.streak?.longest || 0) * 25);         // 25 per day of best streak
    karma += ((userDoc.achievements?.length || 0) * 50);    // 50 per achievement
    karma += ((userDoc.favorites?.length || 0) * 2);        // 2 per favorite
    return karma;
  }

  // ---- Skills Breakdown ----
  function calculateSkills(userDoc, problems) {
    const progress = userDoc.progress || {};
    const topicCounts = {};

    for (const [idStr, status] of Object.entries(progress)) {
      if (status !== 'solved') continue;
      const problem = profileProblemMap ? profileProblemMap.get(parseInt(idStr)) : problems.find(p => p.id === parseInt(idStr));
      if (!problem) continue;

      const category = problem.category || 'general';
      if (!topicCounts[category]) topicCounts[category] = { solved: 0, total: 0 };
      topicCounts[category].solved++;
    }

    // Count totals per category
    problems.forEach(p => {
      const cat = p.category || 'general';
      if (!topicCounts[cat]) topicCounts[cat] = { solved: 0, total: 0 };
      topicCounts[cat].total++;
    });

    // Categorize by proficiency
    const advanced = [];
    const intermediate = [];
    const fundamental = [];

    for (const [topic, data] of Object.entries(topicCounts)) {
      if (data.solved === 0) continue;
      const pct = data.total > 0 ? data.solved / data.total : 0;
      const entry = { topic, solved: data.solved, total: data.total, pct };
      if (pct >= 0.5) advanced.push(entry);
      else if (pct >= 0.2) intermediate.push(entry);
      else fundamental.push(entry);
    }

    return { advanced, intermediate, fundamental };
  }

  // ---- Recent Solved ----
  function getRecentSolved(userDoc, problems) {
    const progress = userDoc.progress || {};
    const pMap = profileProblemMap || new Map(problems.map(p => [p.id, p]));
    return Object.entries(progress)
      .filter(([, v]) => v === 'solved')
      .slice(-20)
      .reverse()
      .map(([id]) => {
        return pMap.get(parseInt(id)) || { id: parseInt(id), title: 'Problem #' + id, difficulty: 'medium' };
      });
  }

  // ---- Heatmap Data ----
  function buildHeatmapData(userDoc) {
    // Build a 365-day activity map
    // For now, create a simulated heatmap based on solved count
    // In a real app, you'd store solve dates in Firestore
    const data = {};
    const today = new Date();

    // Spread solved problems across the last year with some randomness seeded by streak
    const progress = userDoc.progress || {};
    const solvedIds = Object.entries(progress).filter(([, v]) => v === 'solved').map(([id]) => parseInt(id));

    // Distribute solves across recent days
    solvedIds.forEach((id, i) => {
      const daysAgo = Math.floor((i / solvedIds.length) * 365);
      const date = new Date(today);
      date.setDate(date.getDate() - daysAgo);
      const key = date.toISOString().split('T')[0];
      data[key] = (data[key] || 0) + 1;
    });

    return data;
  }

  // ---- Render: Solved Ring ----
  function buildSolvedRing(solved, total) {
    const r = 50, c = 2 * Math.PI * r;
    const pct = total > 0 ? solved / total : 0;
    const offset = c * (1 - pct);
    return `
      <svg viewBox="0 0 120 120" class="solved-ring__svg">
        <circle cx="60" cy="60" r="${r}" fill="none" stroke="var(--border-color)" stroke-width="8"/>
        <circle cx="60" cy="60" r="${r}" fill="none" stroke="var(--color-accent, #4c8bf5)" stroke-width="8"
          stroke-dasharray="${c}" stroke-dashoffset="${offset}" stroke-linecap="round"
          transform="rotate(-90 60 60)" style="transition:stroke-dashoffset 1s ease"/>
        <text x="60" y="55" text-anchor="middle" fill="var(--text-bright)" font-size="22" font-weight="700">${solved}</text>
        <text x="60" y="72" text-anchor="middle" fill="var(--text-muted)" font-size="11">/ ${total}</text>
      </svg>
    `;
  }

  // ---- Render: Badges ----
  function renderBadgesCard(userDoc) {
    if (typeof Achievements === 'undefined') return '<div style="color:var(--text-muted);padding:var(--space-4)">Achievements loading...</div>';

    const all = Achievements.getAll(userDoc);
    const unlocked = all.filter(a => a.unlocked);
    const locked = all.filter(a => !a.unlocked);

    if (unlocked.length === 0) {
      return `<div style="color:var(--text-muted);padding:var(--space-4);text-align:center">
        <div style="font-size:2rem;margin-bottom:var(--space-2)">\uD83C\uDFC5</div>
        <div>No badges earned yet. Start solving problems!</div>
      </div>`;
    }

    return `
      <div class="badges-grid">
        ${unlocked.map(a => `
          <div class="badge-item badge-item--unlocked" title="${a.name}: ${a.description}">
            <span class="badge-item__icon">${a.icon}</span>
            <span class="badge-item__name">${a.name}</span>
          </div>
        `).join('')}
        ${locked.slice(0, 3).map(a => `
          <div class="badge-item badge-item--locked" title="Locked: ${a.description}">
            <span class="badge-item__icon">\uD83D\uDD12</span>
            <span class="badge-item__name">${a.name}</span>
          </div>
        `).join('')}
      </div>
    `;
  }

  // ---- Render: Heatmap ----
  function renderHeatmap(data) {
    const today = new Date();
    const weeks = 52;
    const days = ['', 'Mon', '', 'Wed', '', 'Fri', ''];
    let html = '<div class="heatmap">';

    // Day labels
    html += '<div class="heatmap__labels">';
    days.forEach(d => { html += `<div class="heatmap__day-label">${d}</div>`; });
    html += '</div>';

    // Grid
    html += '<div class="heatmap__grid">';
    for (let w = weeks - 1; w >= 0; w--) {
      html += '<div class="heatmap__week">';
      for (let d = 0; d < 7; d++) {
        const date = new Date(today);
        date.setDate(date.getDate() - (w * 7 + (6 - d)));
        const key = date.toISOString().split('T')[0];
        const count = data[key] || 0;
        const level = count === 0 ? 0 : count <= 2 ? 1 : count <= 4 ? 2 : count <= 6 ? 3 : 4;
        html += `<div class="heatmap__cell heatmap__cell--${level}" title="${key}: ${count} problems"></div>`;
      }
      html += '</div>';
    }
    html += '</div>';

    // Legend
    html += `<div class="heatmap__legend">
      <span>Less</span>
      <div class="heatmap__cell heatmap__cell--0"></div>
      <div class="heatmap__cell heatmap__cell--1"></div>
      <div class="heatmap__cell heatmap__cell--2"></div>
      <div class="heatmap__cell heatmap__cell--3"></div>
      <div class="heatmap__cell heatmap__cell--4"></div>
      <span>More</span>
    </div>`;

    html += '</div>';
    return html;
  }

  // ---- Render: Skills ----
  function renderSkills(skills) {
    function skillSection(title, items, color) {
      if (items.length === 0) return '';
      return `
        <div class="skills-section">
          <div class="skills-section__title" style="color:${color}">${title}</div>
          <div class="skills-tags">
            ${items.map(s => `
              <span class="skill-tag" style="border-color:${color}">
                ${formatTopicName(s.topic)} <span class="skill-tag__count">x${s.solved}</span>
              </span>
            `).join('')}
          </div>
        </div>
      `;
    }

    const html = skillSection('Advanced', skills.advanced, 'var(--color-hard, #ef4444)')
      + skillSection('Intermediate', skills.intermediate, 'var(--color-medium, #f59e0b)')
      + skillSection('Fundamental', skills.fundamental, 'var(--color-easy, #22c55e)');

    return html || '<div style="color:var(--text-muted);padding:var(--space-4)">Solve problems to see your skill breakdown.</div>';
  }

  function formatTopicName(slug) {
    return slug.replace(/-/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
  }

  // ---- Render: Recent Tab ----
  function renderRecentTab(recentSolved) {
    if (recentSolved.length === 0) {
      return '<div style="color:var(--text-muted);padding:var(--space-4);text-align:center">No solved problems yet.</div>';
    }
    return `
      <div class="recent-list">
        ${recentSolved.map(p => `
          <a class="recent-item" href="problems.html?id=${p.id}">
            <span class="badge badge--${p.difficulty}" style="font-size:10px">${p.difficulty}</span>
            <span class="recent-item__title">${p.title}</span>
          </a>
        `).join('')}
      </div>
    `;
  }

  // ---- Render: Attempted Tab ----
  function renderAttemptedTab(problems) {
    const userDoc = Auth.getUserDoc();
    const progress = userDoc?.progress || {};
    const pMap = profileProblemMap || new Map(problems.map(p => [p.id, p]));
    const attemptedProblems = Object.entries(progress)
      .filter(([, v]) => v === 'attempted')
      .map(([id]) => {
        return pMap.get(parseInt(id)) || { id: parseInt(id), title: 'Problem #' + id, difficulty: 'medium' };
      });

    if (attemptedProblems.length === 0) {
      return '<div style="color:var(--text-muted);padding:var(--space-4);text-align:center">No attempted problems yet. Start practicing!</div>';
    }
    return `
      <div class="recent-list">
        ${attemptedProblems.map(p => `
          <a class="recent-item" href="problems.html?id=${p.id}">
            <span class="badge badge--${p.difficulty}" style="font-size:10px">${p.difficulty}</span>
            <span class="recent-item__title">${p.title}</span>
          </a>
        `).join('')}
      </div>
    `;
  }

  // ---- Render: Favorites Tab ----
  function renderFavoritesTab(problems) {
    const userDoc = Auth.getUserDoc();
    const favorites = userDoc?.favorites || [];
    if (favorites.length === 0) {
      return '<div style="color:var(--text-muted);padding:var(--space-4);text-align:center">No favorites yet. Heart problems you want to revisit!</div>';
    }
    const pMap = profileProblemMap || new Map(problems.map(p => [p.id, p]));
    const favProblems = favorites.map(id => pMap.get(id)).filter(Boolean);
    return `
      <div class="recent-list">
        ${favProblems.map(p => `
          <a class="recent-item" href="problems.html?id=${p.id}">
            <span class="badge badge--${p.difficulty}" style="font-size:10px">${p.difficulty}</span>
            <span class="recent-item__title">${p.title}</span>
          </a>
        `).join('')}
      </div>
    `;
  }

  // ---- Render: Collections Tab ----
  function renderCollectionsTab(problems) {
    const userDoc = Auth.getUserDoc();
    const collections = userDoc?.collections || [];
    if (collections.length === 0) {
      return '<div style="color:var(--text-muted);padding:var(--space-4);text-align:center">No saved lists yet. Use the bookmark icon on problems to create lists!</div>';
    }
    return `
      <div class="collections-list">
        ${collections.map(col => {
          const pMap = profileProblemMap || new Map(problems.map(p => [p.id, p]));
          const colProblems = col.problemIds.map(id => pMap.get(id)).filter(Boolean);
          return `
            <div class="collection-card">
              <div class="collection-card__header">
                <span class="collection-card__name">${col.name}</span>
                <span class="collection-card__count">${col.problemIds.length} problems</span>
              </div>
              ${colProblems.length > 0 ? `
                <div class="recent-list">
                  ${colProblems.slice(0, 5).map(p => `
                    <a class="recent-item" href="problems.html?id=${p.id}">
                      <span class="badge badge--${p.difficulty}" style="font-size:10px">${p.difficulty}</span>
                      <span class="recent-item__title">${p.title}</span>
                    </a>
                  `).join('')}
                  ${colProblems.length > 5 ? `<div style="padding:var(--space-2);font-size:var(--text-xs);color:var(--text-muted);text-align:center">+${colProblems.length - 5} more</div>` : ''}
                </div>
              ` : '<div style="padding:var(--space-3);color:var(--text-muted);font-size:var(--text-sm)">Empty list</div>'}
            </div>
          `;
        }).join('')}
      </div>
    `;
  }

  // ---- Tab Switching ----
  let cachedProblems = null;
  async function switchTab(tab) {
    // Toggle active tab
    document.querySelectorAll('.profile-tab').forEach(t => t.classList.remove('profile-tab--active'));
    if (event && event.target) event.target.classList.add('profile-tab--active');

    const content = document.getElementById('profile-tab-content');
    if (!content) return;

    // Use index data (fast) instead of full data
    if (!cachedProblems) {
      const raw = await DataLoader.problemsIndex();
      cachedProblems = (raw || []).map(p => ({
        id: p.id,
        title: p.t || p.title || '',
        category: p.c || p.category || 'probability',
        difficulty: p.d || p.difficulty || 'medium',
        type: p.y || p.type || 'calculation',
      }));
    }
    const userDoc = Auth.getUserDoc();

    if (tab === 'recent') {
      const recent = getRecentSolved(userDoc, cachedProblems || []);
      content.innerHTML = renderRecentTab(recent);
    } else if (tab === 'attempted') {
      content.innerHTML = renderAttemptedTab(cachedProblems || []);
    } else if (tab === 'favorites') {
      content.innerHTML = renderFavoritesTab(cachedProblems || []);
    } else if (tab === 'collections') {
      content.innerHTML = renderCollectionsTab(cachedProblems || []);
    }
  }

  return { init, switchTab };
})();
