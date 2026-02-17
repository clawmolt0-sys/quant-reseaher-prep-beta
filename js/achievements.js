/* ============================================
   ACHIEVEMENTS — Badge system with toast alerts
   ============================================ */

const Achievements = (() => {
  const ACHIEVEMENTS = [
    { id: 'first-solve',  name: 'First Steps',       icon: '\uD83C\uDFAF', desc: 'Solve your first problem',       check: d => getTotalSolved(d) >= 1 },
    { id: 'solver-10',    name: 'Getting Warmed Up',  icon: '\uD83D\uDD1F', desc: 'Solve 10 problems',              check: d => getTotalSolved(d) >= 10 },
    { id: 'solver-50',    name: 'Problem Crusher',    icon: '\uD83D\uDCAA', desc: 'Solve 50 problems',              check: d => getTotalSolved(d) >= 50 },
    { id: 'solver-100',   name: 'Centurion',          icon: '\uD83D\uDCAF', desc: 'Solve 100 problems',             check: d => getTotalSolved(d) >= 100 },
    { id: 'solver-500',   name: 'Legend',              icon: '\uD83C\uDFC6', desc: 'Solve 500 problems',             check: d => getTotalSolved(d) >= 500 },
    { id: 'streak-7',     name: 'Week Warrior',       icon: '\uD83D\uDD25', desc: 'Achieve a 7-day streak',         check: d => (d.streak?.longest || 0) >= 7 },
    { id: 'streak-30',    name: 'Consistency King',   icon: '\uD83D\uDC51', desc: 'Achieve a 30-day streak',        check: d => (d.streak?.longest || 0) >= 30 },
    { id: 'easy-clear',   name: 'Easy Street',        icon: '\uD83D\uDFE2', desc: 'Solve all easy problems',        check: d => (d.stats?.easy?.solved || 0) >= 400 },
    { id: 'hard-10',      name: 'Hard Hitter',        icon: '\uD83D\uDD34', desc: 'Solve 10 hard problems',         check: d => (d.stats?.hard?.solved || 0) >= 10 },
    { id: 'level-10',     name: 'Double Digits',      icon: '\u2B50',       desc: 'Reach level 10',                 check: d => (d.level || 1) >= 10 },
    { id: 'collector',    name: 'Bookworm',           icon: '\uD83D\uDCDA', desc: 'Favorite 20 problems',           check: d => (d.favorites?.length || 0) >= 20 },
    { id: 'organizer',    name: 'Organized Mind',     icon: '\uD83D\uDDC2\uFE0F', desc: 'Create 3 collections',     check: d => (d.collections?.length || 0) >= 3 },
  ];

  function getTotalSolved(d) {
    if (!d.stats) return 0;
    return (d.stats.easy?.solved || 0) + (d.stats.medium?.solved || 0) + (d.stats.hard?.solved || 0);
  }

  // Check which achievements are newly earned
  function check(userDoc) {
    if (!userDoc) return [];
    const existing = userDoc.achievements || [];
    const newBadges = [];

    for (const a of ACHIEVEMENTS) {
      if (!existing.includes(a.id) && a.check(userDoc)) {
        newBadges.push(a.id);
      }
    }

    return newBadges;
  }

  // Award an achievement: save to Firestore + show toast
  async function award(achievementId) {
    const db = FirebaseConfig.getDb();
    const user = Auth.getUser();
    const doc = Auth.getUserDoc();
    if (!db || !user || !doc) return;

    try {
      if (!doc.achievements) doc.achievements = [];
      if (!doc.achievements.includes(achievementId)) {
        doc.achievements.push(achievementId);
        await db.collection('users').doc(user.uid).set({
          achievements: firebase.firestore.FieldValue.arrayUnion(achievementId),
        }, { merge: true });
      }

      const achievement = ACHIEVEMENTS.find(a => a.id === achievementId);
      if (achievement) {
        showToast(achievement);
      }
    } catch (err) {
      console.error('[Achievements] Award error:', err);
    }
  }

  // Toast notification
  function showToast(achievement) {
    // Remove existing toasts
    const existing = document.querySelector('.achievement-toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.className = 'achievement-toast';
    toast.innerHTML = `
      <div class="achievement-toast__icon">${achievement.icon}</div>
      <div class="achievement-toast__content">
        <div class="achievement-toast__label">Achievement Unlocked!</div>
        <div class="achievement-toast__name">${achievement.name}</div>
      </div>
    `;

    document.body.appendChild(toast);

    // Trigger animation
    requestAnimationFrame(() => {
      toast.classList.add('achievement-toast--show');
    });

    // Auto-dismiss after 4 seconds
    setTimeout(() => {
      toast.classList.remove('achievement-toast--show');
      setTimeout(() => toast.remove(), 300);
    }, 4000);
  }

  // Get all achievements with unlock status
  function getAll(userDoc) {
    const existing = (userDoc && userDoc.achievements) ? userDoc.achievements : [];
    return ACHIEVEMENTS.map(a => ({
      ...a,
      unlocked: existing.includes(a.id),
    }));
  }

  // Render full achievement grid
  function renderGrid(container, userDoc) {
    const all = getAll(userDoc);
    container.innerHTML = all.map(a => `
      <div class="achievement-card ${a.unlocked ? '' : 'achievement-card--locked'}">
        <div class="achievement-card__icon">${a.unlocked ? a.icon : '\u2753'}</div>
        <div class="achievement-card__name">${a.unlocked ? a.name : '???'}</div>
        <div class="achievement-card__desc">${a.desc}</div>
      </div>
    `).join('');
  }

  return { check, award, showToast, getAll, renderGrid };
})();
