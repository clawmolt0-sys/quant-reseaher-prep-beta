/* ============================================
   AUTH — Firebase Authentication + Firestore
   Google & GitHub OAuth, progress sync, tier,
   XP/levels, streaks, favorites, enhanced profile
   ============================================ */

const Auth = (() => {
  let currentUser = null;
  let userDoc = null;
  let migrated = false;
  let allProblems = null; // Set via setProblemData()

  // ---- Admin emails (always get pro tier) ----
  const ADMIN_EMAILS = [
    'alexwuyinchen@gmail.com',
  ];

  // ---- XP Config ----
  const XP_TABLE = { easy: 10, medium: 25, hard: 50 };

  function isAdmin(email) {
    return ADMIN_EMAILS.includes((email || '').toLowerCase());
  }

  // ---- Init ----
  function init() {
    FirebaseConfig.init();

    if (!FirebaseConfig.isConfigured()) {
      console.log('[Auth] Firebase not configured, running in local-only mode');
      renderLoginButton();
      return;
    }

    if (!FirebaseConfig.isInitialized()) {
      console.warn('[Auth] Firebase failed to initialize');
      renderLoginButton();
      return;
    }

    const auth = FirebaseConfig.getAuth();
    if (!auth) return;

    auth.onAuthStateChanged(async (user) => {
      if (user) {
        currentUser = user;
        console.log('[Auth] Signed in as', user.displayName);
        await loadUserDoc(user);
        if (!migrated) {
          await migrateLocalStorage(user.uid);
          migrated = true;
        }
        // Sync stats for existing users who don't have the new fields
        await syncStatsOnLogin();
        renderUserUI();
      } else {
        currentUser = null;
        userDoc = null;
        migrated = false;
        renderLoginButton();
      }
    });
  }

  // ============================================================
  //  AUTH MODAL (Phase 1)
  // ============================================================

  function showAuthModal() {
    // Close any existing modal
    const existing = document.querySelector('.auth-modal-overlay');
    if (existing) existing.remove();

    const overlay = document.createElement('div');
    overlay.className = 'auth-modal-overlay';
    overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };

    overlay.innerHTML = `
      <div class="auth-modal">
        <button class="account-modal__close" onclick="this.closest('.auth-modal-overlay').remove()">&times;</button>

        <div class="auth-modal__header">
          <div class="auth-modal__icon">\u26A1</div>
          <h2 class="auth-modal__title">Welcome to QR Prep</h2>
          <p class="auth-modal__subtitle">Sign in to track your progress, earn XP, and unlock achievements.</p>
        </div>

        <div class="auth-modal__providers">
          <button class="auth-provider-btn auth-provider-btn--google" onclick="Auth.signInWithGoogle()">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
              <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
              <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18A10.96 10.96 0 001 12c0 1.77.42 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
              <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
            </svg>
            <span>Continue with Google</span>
          </button>
          <button class="auth-provider-btn auth-provider-btn--github" onclick="Auth.signInWithGitHub()">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
            </svg>
            <span>Continue with GitHub</span>
          </button>
        </div>

        <div class="auth-modal__divider"><span>or</span></div>

        <div class="auth-modal__toggle" id="auth-toggle-text">
          <span class="auth-modal__toggle-text">Already a member? <a href="#" onclick="event.preventDefault();">Log in</a></span>
        </div>

        <div class="auth-modal__footer">
          By continuing, you agree to our Terms of Service.
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
  }

  // ---- Google Sign In ----
  async function signInWithGoogle() {
    // Close auth modal if open
    const modal = document.querySelector('.auth-modal-overlay');
    if (modal) modal.remove();

    if (!FirebaseConfig.isConfigured()) {
      showAuthNotConfigured();
      return;
    }

    const auth = FirebaseConfig.getAuth();
    if (!auth) return;

    try {
      const provider = new firebase.auth.GoogleAuthProvider();
      await auth.signInWithPopup(provider);
    } catch (err) {
      if (err.code === 'auth/unauthorized-domain') {
        console.warn('[Auth] Popup blocked (unauthorized domain), trying redirect...');
        try {
          const provider = new firebase.auth.GoogleAuthProvider();
          await auth.signInWithRedirect(provider);
        } catch (redirectErr) {
          console.error('[Auth] Redirect sign in also failed:', redirectErr);
          showDomainError();
        }
      } else if (err.code === 'auth/popup-blocked') {
        const provider = new firebase.auth.GoogleAuthProvider();
        await auth.signInWithRedirect(provider);
      } else if (err.code !== 'auth/popup-closed-by-user') {
        console.error('[Auth] Sign in error:', err);
      }
    }
  }

  // ---- GitHub Sign In ----
  async function signInWithGitHub() {
    const modal = document.querySelector('.auth-modal-overlay');
    if (modal) modal.remove();

    if (!FirebaseConfig.isConfigured()) {
      showAuthNotConfigured();
      return;
    }

    const auth = FirebaseConfig.getAuth();
    if (!auth) return;

    try {
      const provider = new firebase.auth.GithubAuthProvider();
      await auth.signInWithPopup(provider);
    } catch (err) {
      if (err.code === 'auth/unauthorized-domain') {
        try {
          const provider = new firebase.auth.GithubAuthProvider();
          await auth.signInWithRedirect(provider);
        } catch (redirectErr) {
          console.error('[Auth] GitHub redirect failed:', redirectErr);
          showDomainError();
        }
      } else if (err.code === 'auth/popup-blocked') {
        const provider = new firebase.auth.GithubAuthProvider();
        await auth.signInWithRedirect(provider);
      } else if (err.code !== 'auth/popup-closed-by-user') {
        console.error('[Auth] GitHub sign in error:', err);
      }
    }
  }

  // ---- Domain not authorized error dialog ----
  function showDomainError() {
    const overlay = document.createElement('div');
    overlay.className = 'account-modal-overlay';
    overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };

    overlay.innerHTML = `
      <div class="account-modal" style="max-width:460px">
        <button class="account-modal__close" onclick="this.closest('.account-modal-overlay').remove()">&times;</button>
        <div style="text-align:center;padding:var(--space-4)">
          <div style="font-size:2rem;margin-bottom:var(--space-3)">&#x1F6A8;</div>
          <h3 style="margin-bottom:var(--space-2)">Domain Not Authorized</h3>
          <p style="color:var(--text-secondary);font-size:var(--text-sm);line-height:1.6;margin-bottom:var(--space-4)">
            This domain needs to be added to Firebase's authorized domains list.
            Go to <strong>Firebase Console &rarr; Authentication &rarr; Settings &rarr; Authorized domains</strong>
            and add <code style="font-size:var(--text-xs);background:var(--bg-card);padding:2px 6px;border-radius:4px">${window.location.hostname}</code>.
          </p>
          <button class="btn btn--secondary btn--sm" onclick="this.closest('.account-modal-overlay').remove()">Got it</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
  }

  // ---- Sign Out ----
  async function signOut() {
    const auth = FirebaseConfig.getAuth();
    if (!auth) return;

    try {
      await auth.signOut();
      currentUser = null;
      userDoc = null;
      closeDropdown();
    } catch (err) {
      console.error('[Auth] Sign out error:', err);
    }
  }

  // ============================================================
  //  FIRESTORE — User Doc, Progress, Stats
  // ============================================================

  async function loadUserDoc(user) {
    const db = FirebaseConfig.getDb();
    if (!db) return;

    try {
      const docRef = db.collection('users').doc(user.uid);
      const doc = await docRef.get();

      if (doc.exists) {
        userDoc = doc.data();
        // Auto-upgrade admins to pro
        if (isAdmin(user.email) && userDoc.tier !== 'pro') {
          await docRef.update({ tier: 'pro' });
          userDoc.tier = 'pro';
        }
      } else {
        // Create new user doc with extended fields
        const tier = isAdmin(user.email) ? 'pro' : 'free';
        userDoc = {
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
          tier: tier,
          joinDate: firebase.firestore.FieldValue.serverTimestamp(),
          progress: {},
          stats: { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } },
          xp: 0,
          level: 1,
          streak: { current: 0, longest: 0, lastActivityDate: null },
          favorites: [],
          collections: [],
          achievements: [],
        };
        await docRef.set(userDoc);
      }
    } catch (err) {
      console.error('[Auth] Error loading user doc:', err);
      userDoc = { tier: 'free', progress: {}, stats: { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } }, xp: 0, level: 1, streak: { current: 0, longest: 0, lastActivityDate: null }, favorites: [], collections: [], achievements: [] };
    }
  }

  // Sync stats for existing users who don't have the new fields
  async function syncStatsOnLogin() {
    if (!currentUser || !userDoc) return;
    // If user already has stats field, skip
    if (userDoc.stats && typeof userDoc.xp === 'number') return;

    const problems = allProblems || (await DataLoader.problems()) || [];
    const progress = userDoc.progress || {};

    const stats = { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } };
    let xp = 0;

    for (const [idStr, status] of Object.entries(progress)) {
      const id = parseInt(idStr);
      const problem = problems.find(p => p.id === id);
      const diff = problem ? problem.difficulty : 'medium';
      if (stats[diff]) {
        if (status === 'solved') {
          stats[diff].solved++;
          xp += XP_TABLE[diff] || 0;
        } else if (status === 'attempted') {
          stats[diff].attempted++;
        }
      }
    }

    const level = calculateLevel(xp).level;

    const update = {
      stats,
      xp,
      level,
      streak: userDoc.streak || { current: 0, longest: 0, lastActivityDate: null },
      favorites: userDoc.favorites || [],
      collections: userDoc.collections || [],
      achievements: userDoc.achievements || [],
    };

    try {
      const db = FirebaseConfig.getDb();
      if (db) {
        await db.collection('users').doc(currentUser.uid).update(update);
        Object.assign(userDoc, update);
      }
    } catch (err) {
      console.error('[Auth] Stats sync error:', err);
    }
  }

  // ---- Migrate localStorage to Firestore ----
  async function migrateLocalStorage(uid) {
    const db = FirebaseConfig.getDb();
    if (!db) return;

    try {
      const migKey = 'qr-prep-migrated-' + uid;
      if (localStorage.getItem(migKey)) return;

      const progress = {};
      let count = 0;
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith('qr-prep-status-')) {
          const problemId = key.replace('qr-prep-status-', '');
          const status = localStorage.getItem(key);
          if (status) {
            progress[problemId] = status;
            count++;
          }
        }
      }

      if (count > 0) {
        const docRef = db.collection('users').doc(uid);
        const existing = userDoc?.progress || {};
        const merged = { ...progress, ...existing };
        await docRef.update({ progress: merged });
        userDoc.progress = merged;
        console.log('[Auth] Migrated', count, 'status entries to Firestore');
      }

      localStorage.setItem(migKey, 'true');
    } catch (err) {
      console.error('[Auth] Migration error:', err);
    }
  }

  // ============================================================
  //  STATUS SYNC + XP/STREAK (Phase 4)
  // ============================================================

  async function saveStatus(id, status) {
    // Always save to localStorage as fallback
    try {
      if (status) {
        localStorage.setItem('qr-prep-status-' + id, status);
      } else {
        localStorage.removeItem('qr-prep-status-' + id);
      }
    } catch (e) { /* ignore */ }

    if (!currentUser) return;

    const db = FirebaseConfig.getDb();
    if (!db) return;

    const previousStatus = (userDoc && userDoc.progress) ? userDoc.progress[id] : '';

    try {
      const docRef = db.collection('users').doc(currentUser.uid);
      if (status) {
        await docRef.update({ ['progress.' + id]: status });
        if (userDoc) userDoc.progress[id] = status;
      } else {
        await docRef.update({ ['progress.' + id]: firebase.firestore.FieldValue.delete() });
        if (userDoc) delete userDoc.progress[id];
      }

      // XP + stats tracking
      if (status === 'solved' && previousStatus !== 'solved') {
        const diff = getProblemDifficulty(id);
        const xpGain = XP_TABLE[diff] || 0;

        // Update stats
        if (!userDoc.stats) userDoc.stats = { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } };
        if (userDoc.stats[diff]) userDoc.stats[diff].solved++;

        // Update XP + level
        userDoc.xp = (userDoc.xp || 0) + xpGain;
        userDoc.level = calculateLevel(userDoc.xp).level;

        // Update streak
        updateStreak();

        // Save all updates
        await docRef.update({
          stats: userDoc.stats,
          xp: userDoc.xp,
          level: userDoc.level,
          streak: userDoc.streak,
        });

        // Check achievements
        if (typeof Achievements !== 'undefined') {
          const newBadges = Achievements.check(userDoc);
          for (const badge of newBadges) {
            await Achievements.award(badge);
          }
        }
      } else if (status === 'attempted' && !previousStatus) {
        const diff = getProblemDifficulty(id);
        if (!userDoc.stats) userDoc.stats = { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } };
        if (userDoc.stats[diff]) userDoc.stats[diff].attempted++;
        await docRef.update({ stats: userDoc.stats });
      }
    } catch (err) {
      console.error('[Auth] Error saving status:', err);
    }
  }

  function getStatus(id) {
    if (currentUser && userDoc && userDoc.progress) {
      return userDoc.progress[id] || '';
    }
    try { return localStorage.getItem('qr-prep-status-' + id) || ''; }
    catch (e) { return ''; }
  }

  function getProblemDifficulty(id) {
    if (!allProblems) return 'medium';
    const p = allProblems.find(prob => prob.id === parseInt(id));
    return p ? p.difficulty : 'medium';
  }

  function setProblemData(problems) {
    allProblems = problems;
  }

  // ---- Streak Logic ----
  function updateStreak() {
    if (!userDoc) return;
    if (!userDoc.streak) userDoc.streak = { current: 0, longest: 0, lastActivityDate: null };

    const today = new Date().toISOString().split('T')[0];
    const last = userDoc.streak.lastActivityDate;

    if (last === today) {
      // Already active today
      return;
    }

    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

    if (last === yesterday) {
      userDoc.streak.current++;
    } else {
      userDoc.streak.current = 1;
    }

    if (userDoc.streak.current > userDoc.streak.longest) {
      userDoc.streak.longest = userDoc.streak.current;
    }

    userDoc.streak.lastActivityDate = today;
  }

  // ---- XP / Level Calculation ----
  function calculateLevel(xp) {
    // Levels 1-10: 100 XP each, 11+: 250 XP each
    let level = 1;
    let remaining = xp || 0;

    while (remaining > 0) {
      const needed = level <= 10 ? 100 : 250;
      if (remaining >= needed) {
        remaining -= needed;
        level++;
      } else {
        break;
      }
    }

    const currentLevelThreshold = level <= 10 ? 100 : 250;
    const percent = currentLevelThreshold > 0 ? Math.floor((remaining / currentLevelThreshold) * 100) : 0;

    return { level, currentXP: remaining, nextLevelXP: currentLevelThreshold, percent };
  }

  // ============================================================
  //  FAVORITES (Phase 5)
  // ============================================================

  async function toggleFavorite(problemId) {
    if (!currentUser || !userDoc) return false;
    const db = FirebaseConfig.getDb();
    if (!db) return false;

    const docRef = db.collection('users').doc(currentUser.uid);
    const id = parseInt(problemId);

    try {
      if (!userDoc.favorites) userDoc.favorites = [];

      if (userDoc.favorites.includes(id)) {
        await docRef.update({ favorites: firebase.firestore.FieldValue.arrayRemove(id) });
        userDoc.favorites = userDoc.favorites.filter(f => f !== id);
        return false; // unfavorited
      } else {
        await docRef.update({ favorites: firebase.firestore.FieldValue.arrayUnion(id) });
        userDoc.favorites.push(id);

        // Check bookworm achievement
        if (typeof Achievements !== 'undefined') {
          const newBadges = Achievements.check(userDoc);
          for (const badge of newBadges) await Achievements.award(badge);
        }
        return true; // favorited
      }
    } catch (err) {
      console.error('[Auth] Favorite error:', err);
      return false;
    }
  }

  function isFavorited(problemId) {
    if (!userDoc || !userDoc.favorites) return false;
    return userDoc.favorites.includes(parseInt(problemId));
  }

  function getFavorites() {
    return (userDoc && userDoc.favorites) ? userDoc.favorites : [];
  }

  // ---- Tier ----
  function getTier() {
    if (currentUser && isAdmin(currentUser.email)) return 'pro';
    if (!currentUser || !userDoc) return 'free';
    return userDoc.tier || 'free';
  }

  function isLoggedIn() { return !!currentUser; }
  function getUser() { return currentUser; }
  function getUserDoc() { return userDoc; }

  // ============================================================
  //  UI: Login Button
  // ============================================================

  function renderLoginButton() {
    const container = document.getElementById('auth-container');
    if (!container) return;

    container.innerHTML = `
      <button class="nav__auth-btn" onclick="Auth.showAuthModal()">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
          <circle cx="12" cy="7" r="4"/>
        </svg>
        <span>Sign In</span>
      </button>
    `;
  }

  // ============================================================
  //  UI: Logged-in User Menu
  // ============================================================

  function renderUserUI() {
    const container = document.getElementById('auth-container');
    if (!container) return;

    const photoURL = currentUser.photoURL || '';
    const name = currentUser.displayName || currentUser.email || 'User';
    const tier = getTier();
    const initial = name.charAt(0).toUpperCase();
    const levelInfo = calculateLevel(userDoc ? userDoc.xp : 0);

    container.innerHTML = `
      <div class="nav__user-menu">
        <button class="nav__user-btn" onclick="Auth.toggleDropdown()">
          ${photoURL
            ? `<img class="nav__user-avatar" src="${photoURL}" alt="${name}" referrerpolicy="no-referrer">`
            : `<span class="nav__user-avatar nav__user-avatar--initials">${initial}</span>`
          }
          <span class="nav__user-name">${name.split(' ')[0]}</span>
          <span class="nav__user-level-badge">Lv.${levelInfo.level}</span>
        </button>
        <div class="nav__user-dropdown" id="user-dropdown">
          <div class="nav__dropdown-header">
            <span class="nav__dropdown-name">${name}</span>
            <span class="nav__dropdown-email">${currentUser.email}</span>
            <span class="tier-badge tier-badge--${tier}" style="margin-top:4px">${tier}</span>
          </div>
          <div class="nav__dropdown-divider"></div>
          <button class="nav__dropdown-item" onclick="Auth.showAccount()">
            <span>\uD83D\uDCCA Profile & Stats</span>
          </button>
          <div class="nav__dropdown-divider"></div>
          <button class="nav__dropdown-item nav__dropdown-item--danger" onclick="Auth.signOut()">
            <span>Sign Out</span>
          </button>
        </div>
      </div>
    `;
  }

  // ---- Dropdown Toggle ----
  function toggleDropdown() {
    const dd = document.getElementById('user-dropdown');
    if (!dd) return;
    dd.classList.toggle('nav__user-dropdown--open');
    if (dd.classList.contains('nav__user-dropdown--open')) {
      setTimeout(() => { document.addEventListener('click', closeDropdownOnOutside); }, 0);
    }
  }

  function closeDropdownOnOutside(e) {
    const menu = document.querySelector('.nav__user-menu');
    if (menu && !menu.contains(e.target)) closeDropdown();
  }

  function closeDropdown() {
    const dd = document.getElementById('user-dropdown');
    if (dd) dd.classList.remove('nav__user-dropdown--open');
    document.removeEventListener('click', closeDropdownOnOutside);
  }

  // ============================================================
  //  ENHANCED PROFILE MODAL (Phase 3)
  // ============================================================

  async function showAccount() {
    closeDropdown();
    if (!currentUser || !userDoc) return;

    const problems = allProblems || (await DataLoader.problems()) || [];
    const progress = userDoc.progress || {};
    const stats = userDoc.stats || { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } };
    const xp = userDoc.xp || 0;
    const levelInfo = calculateLevel(xp);
    const streak = userDoc.streak || { current: 0, longest: 0 };
    const tier = getTier();
    const joinDate = userDoc.joinDate
      ? (userDoc.joinDate.toDate ? userDoc.joinDate.toDate().toLocaleDateString() : new Date(userDoc.joinDate).toLocaleDateString())
      : 'Recently';

    // Count totals per difficulty
    const totalEasy = problems.filter(p => p.difficulty === 'easy').length;
    const totalMedium = problems.filter(p => p.difficulty === 'medium').length;
    const totalHard = problems.filter(p => p.difficulty === 'hard').length;

    const totalSolved = (stats.easy?.solved || 0) + (stats.medium?.solved || 0) + (stats.hard?.solved || 0);
    const totalAttempted = (stats.easy?.attempted || 0) + (stats.medium?.attempted || 0) + (stats.hard?.attempted || 0);

    // Progress ring helper
    function ring(solved, total, color, label) {
      const r = 32, c = 2 * Math.PI * r;
      const pct = total > 0 ? solved / total : 0;
      const offset = c * (1 - pct);
      return `
        <div class="difficulty-stat">
          <svg class="progress-ring" viewBox="0 0 80 80">
            <circle class="progress-ring__bg" cx="40" cy="40" r="${r}" fill="none" stroke="var(--border-color)" stroke-width="6"/>
            <circle class="progress-ring__fill" cx="40" cy="40" r="${r}" fill="none" stroke="${color}" stroke-width="6"
              stroke-dasharray="${c}" stroke-dashoffset="${offset}" stroke-linecap="round"
              transform="rotate(-90 40 40)" style="transition:stroke-dashoffset 0.8s ease"/>
            <text x="40" y="38" text-anchor="middle" fill="var(--text-bright)" font-size="14" font-weight="700">${solved}</text>
            <text x="40" y="52" text-anchor="middle" fill="var(--text-muted)" font-size="9">/ ${total}</text>
          </svg>
          <div class="difficulty-stat__label" style="color:${color}">${label}</div>
        </div>
      `;
    }

    // Recent activity (last 5 solved)
    const recentKeys = Object.entries(progress)
      .filter(([, v]) => v === 'solved')
      .slice(-5)
      .reverse();
    const recentHTML = recentKeys.length > 0
      ? recentKeys.map(([id]) => {
          const p = problems.find(pr => pr.id === parseInt(id));
          return `<div class="profile-activity__item">
            <span class="profile-activity__dot" style="background:var(--color-${p ? p.difficulty : 'medium'})"></span>
            <span class="profile-activity__title">${p ? p.title : 'Problem #' + id}</span>
          </div>`;
        }).join('')
      : '<div style="color:var(--text-muted);font-size:var(--text-xs)">No problems solved yet. Start practicing!</div>';

    // Achievements preview
    const achievementsHTML = typeof Achievements !== 'undefined'
      ? (() => {
          const all = Achievements.getAll(userDoc);
          const unlocked = all.filter(a => a.unlocked);
          const preview = unlocked.slice(0, 6);
          return preview.length > 0
            ? `<div class="profile-achievements-preview">
                <div class="profile-achievements-preview__label">Achievements (${unlocked.length}/${all.length})</div>
                <div class="profile-achievements-preview__grid">
                  ${preview.map(a => `<span class="achievement-mini" title="${a.name}">${a.icon}</span>`).join('')}
                  ${unlocked.length > 6 ? `<span class="achievement-mini achievement-mini--more">+${unlocked.length - 6}</span>` : ''}
                </div>
              </div>`
            : '';
        })()
      : '';

    const overlay = document.createElement('div');
    overlay.className = 'account-modal-overlay';
    overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };

    overlay.innerHTML = `
      <div class="account-modal" style="max-width:520px">
        <button class="account-modal__close" onclick="this.closest('.account-modal-overlay').remove()">&times;</button>

        <!-- Header -->
        <div class="account-modal__header">
          ${currentUser.photoURL
            ? `<img class="account-modal__avatar" src="${currentUser.photoURL}" alt="" referrerpolicy="no-referrer">`
            : `<span class="account-modal__avatar account-modal__avatar--initials">${(currentUser.displayName || 'U').charAt(0)}</span>`
          }
          <div class="account-modal__info">
            <div class="account-modal__name">${currentUser.displayName || 'User'}</div>
            <div class="account-modal__email">${currentUser.email}</div>
            <div style="display:flex;gap:var(--space-2);margin-top:4px;align-items:center">
              <span class="tier-badge tier-badge--${tier}">${tier === 'pro' ? 'Pro' : 'Free'}</span>
              <span style="font-size:10px;color:var(--text-muted)">Member since ${joinDate}</span>
            </div>
          </div>
        </div>

        <!-- Level & XP Bar -->
        <div class="profile-level">
          <div class="profile-level__header">
            <span class="profile-level__badge">Level ${levelInfo.level}</span>
            <span class="profile-level__text">${levelInfo.currentXP} / ${levelInfo.nextLevelXP} XP</span>
          </div>
          <div class="profile-level__bar">
            <div class="profile-level__fill" style="width:${levelInfo.percent}%"></div>
          </div>
        </div>

        <!-- Difficulty Breakdown -->
        <div class="difficulty-stats">
          ${ring(stats.easy?.solved || 0, totalEasy, 'var(--color-easy)', 'Easy')}
          ${ring(stats.medium?.solved || 0, totalMedium, 'var(--color-medium)', 'Medium')}
          ${ring(stats.hard?.solved || 0, totalHard, 'var(--color-hard)', 'Hard')}
        </div>

        <!-- Streak + Stats Row -->
        <div class="profile-stats-row">
          <div class="profile-stat-card">
            <div class="profile-stat-card__icon">\uD83D\uDD25</div>
            <div class="profile-stat-card__value">${streak.current || 0}</div>
            <div class="profile-stat-card__label">Day Streak</div>
          </div>
          <div class="profile-stat-card">
            <div class="profile-stat-card__icon">\u2705</div>
            <div class="profile-stat-card__value">${totalSolved}</div>
            <div class="profile-stat-card__label">Solved</div>
          </div>
          <div class="profile-stat-card">
            <div class="profile-stat-card__icon">\uD83D\uDCDD</div>
            <div class="profile-stat-card__value">${totalAttempted}</div>
            <div class="profile-stat-card__label">Attempted</div>
          </div>
          <div class="profile-stat-card">
            <div class="profile-stat-card__icon">\uD83C\uDFC6</div>
            <div class="profile-stat-card__value">${streak.longest || 0}</div>
            <div class="profile-stat-card__label">Best Streak</div>
          </div>
        </div>

        <!-- Recent Activity -->
        <div class="profile-activity">
          <div class="profile-activity__label">Recent Activity</div>
          ${recentHTML}
        </div>

        <!-- Achievements Preview -->
        ${achievementsHTML}

        <!-- Upgrade CTA -->
        ${tier === 'free' ? `
          <div class="account-modal__upgrade">
            <div class="account-modal__upgrade-title">Upgrade to Pro</div>
            <div class="account-modal__upgrade-desc">
              Get access to all 1,090+ problems, detailed solutions, and advanced filters.
            </div>
            <button class="btn btn--primary btn--sm" style="width:100%;margin-top:var(--space-3)">
              Coming Soon
            </button>
          </div>
        ` : ''}
      </div>
    `;

    document.body.appendChild(overlay);
  }

  // ---- Firebase not configured dialog ----
  function showAuthNotConfigured() {
    const overlay = document.createElement('div');
    overlay.className = 'account-modal-overlay';
    overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };

    overlay.innerHTML = `
      <div class="account-modal" style="max-width:420px">
        <button class="account-modal__close" onclick="this.closest('.account-modal-overlay').remove()">&times;</button>
        <div style="text-align:center;padding:var(--space-4)">
          <div style="font-size:2rem;margin-bottom:var(--space-3)">&#x1F512;</div>
          <h3 style="margin-bottom:var(--space-2)">Firebase Not Configured</h3>
          <p style="color:var(--text-secondary);font-size:var(--text-sm);line-height:1.6;margin-bottom:var(--space-4)">
            Authentication requires a Firebase project. To enable sign-in, set up Firebase
            and update the config in <code style="font-size:var(--text-xs);background:var(--bg-card);padding:2px 6px;border-radius:4px">js/firebase-config.js</code>.
          </p>
          <button class="btn btn--secondary btn--sm" onclick="this.closest('.account-modal-overlay').remove()">Got it</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
  }

  return {
    init, showAuthModal, signInWithGoogle, signInWithGitHub, signOut,
    saveStatus, getStatus, getTier,
    isLoggedIn, getUser, getUserDoc,
    setProblemData, calculateLevel,
    toggleFavorite, isFavorited, getFavorites,
    renderLoginButton, renderUserUI,
    toggleDropdown, closeDropdown, showAccount,
  };
})();
