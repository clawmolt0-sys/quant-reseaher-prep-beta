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
  let pendingAuthUpdate = null; // Queued auth state if DOM not ready
  let authSettled = false;       // True once onAuthStateChanged has fully processed
  let authSettledCallbacks = []; // Callbacks waiting for auth to settle

  // ---- Admin emails (always get pro tier) ----
  const ADMIN_EMAILS = [
    'alexwuyinchen@gmail.com',
  ];

  // ---- XP Config ----
  const XP_TABLE = { easy: 10, medium: 25, hard: 50 };

  function isAdmin(email) {
    return ADMIN_EMAILS.includes((email || '').toLowerCase());
  }

  // ---- Check if DOM is ready for rendering ----
  function isDomReady() {
    return document.readyState === 'complete' || document.readyState === 'interactive';
  }

  // ---- Force a DOM reflow and dispatch auth-state-changed event ----
  function forceAuthUIUpdate() {
    const container = document.getElementById('auth-container');
    if (container) {
      // Force reflow to ensure the browser paints the new content
      void container.offsetHeight;
      container.style.display = 'none';
      void container.offsetHeight;
      container.style.display = '';
    }
    // Dispatch custom event so other pages (e.g. profile) can react
    window.dispatchEvent(new CustomEvent('auth-state-changed', {
      detail: { loggedIn: !!currentUser, user: currentUser }
    }));
  }

  // ---- Test Firestore connectivity (detect expired rules) ----
  async function testFirestoreWrite() {
    try {
      const db = FirebaseConfig.getDb();
      if (!db || !currentUser) return;

      const testRef = db.collection('users').doc(currentUser.uid);
      // Try a tiny write to check if rules allow it
      await testRef.set({ _lastSeen: new Date().toISOString() }, { merge: true });
      console.log('[Auth] Firestore write test: OK');
    } catch (err) {
      console.error('[Auth] Firestore write test FAILED:', err.code, err.message);
      if (err.code === 'permission-denied') {
        console.error('=== FIRESTORE RULES LIKELY EXPIRED ===');
        console.error('Go to Firebase Console > Firestore > Rules and update them.');
        console.error('Set: allow read, write: if request.auth != null;');
        // Show a warning toast
        setTimeout(() => {
          const toast = document.createElement('div');
          toast.className = 'qr-toast qr-toast--show';
          toast.style.cssText = 'background:#dc2626;color:white;border:none;position:fixed;bottom:24px;left:50%;transform:translateX(-50%);padding:12px 24px;border-radius:12px;z-index:99999;font-size:14px;box-shadow:0 4px 12px rgba(0,0,0,0.3)';
          toast.innerHTML = '\u26A0\uFE0F Database permissions expired. <a href="https://console.firebase.google.com/project/qrprep/firestore/rules" target="_blank" style="color:#fbbf24;text-decoration:underline">Fix Firestore Rules</a>';
          document.body.appendChild(toast);
          setTimeout(() => toast.remove(), 15000);
        }, 1000);
      }
    }
  }

  // ---- Auth state change handler (extracted to avoid duplication) ----
  async function handleAuthStateChanged(user) {
    // If DOM isn't ready yet, queue the update
    if (!isDomReady()) {
      pendingAuthUpdate = user;
      document.addEventListener('DOMContentLoaded', () => {
        if (pendingAuthUpdate !== null) {
          const queued = pendingAuthUpdate;
          pendingAuthUpdate = null;
          handleAuthStateChanged(queued);
        }
      }, { once: true });
      return;
    }

    if (user) {
      currentUser = user;
      console.log('[Auth] Signed in as', user.displayName);

      // Render the user avatar IMMEDIATELY (before Firestore loads)
      // so the UI feels instant
      renderUserUI();

      // Then load Firestore data in background
      await loadUserDoc(user);
      if (!migrated) {
        await migrateLocalStorage(user.uid);
        migrated = true;
      }
      await syncStatsOnLogin();

      // Re-render with full data (level badge, etc.)
      renderUserUI();
      forceAuthUIUpdate();

      // Test Firestore connectivity (detects expired rules)
      testFirestoreWrite();
    } else {
      currentUser = null;
      userDoc = null;
      migrated = false;
      renderLoginButton();
      forceAuthUIUpdate();
    }

    // Mark auth as settled so profile page and other consumers can proceed
    authSettled = true;
    while (authSettledCallbacks.length > 0) {
      authSettledCallbacks.shift()();
    }
  }

  // Returns a promise that resolves once auth has fully settled (user doc loaded or no user)
  function waitForAuth() {
    if (authSettled) return Promise.resolve();
    return new Promise((resolve) => {
      authSettledCallbacks.push(resolve);
    });
  }

  // ---- Init ----
  function init() {
    // Immediately show a placeholder to prevent empty container flash
    const container = document.getElementById('auth-container');
    if (container && !container.innerHTML.trim()) {
      container.innerHTML = '<div class="nav__auth-loading" style="width:36px;height:36px;border-radius:50%;background:var(--bg-card,#1e1e2e);animation:pulse 1.5s ease-in-out infinite"></div>';
    }

    FirebaseConfig.init();

    if (!FirebaseConfig.isConfigured()) {
      console.log('[Auth] Firebase not configured, running in local-only mode');
      renderLoginButton();
      return;
    }

    if (!FirebaseConfig.isInitialized()) {
      console.warn('[Auth] Firebase not initialized yet, retrying...');
      // Retry after a short delay in case scripts are still loading
      setTimeout(() => {
        FirebaseConfig.init();
        if (FirebaseConfig.isInitialized()) {
          const auth = FirebaseConfig.getAuth();
          if (auth) {
            auth.onAuthStateChanged(handleAuthStateChanged);
          }
        } else {
          console.warn('[Auth] Firebase failed to initialize after retry');
          renderLoginButton();
        }
      }, 1000);
      return;
    }

    const auth = FirebaseConfig.getAuth();
    if (!auth) return;

    auth.onAuthStateChanged(handleAuthStateChanged);

    // Handle redirect-based auth (e.g. on GitHub Pages where popups are blocked)
    auth.getRedirectResult().then((result) => {
      if (result && result.user) {
        console.log('[Auth] Redirect sign-in completed for', result.user.displayName);
        // onAuthStateChanged will fire, but force a UI update just in case
        handleAuthStateChanged(result.user);
      }
    }).catch((err) => {
      if (err.code !== 'auth/credential-already-in-use') {
        console.warn('[Auth] getRedirectResult error:', err.code, err.message);
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

    // Use redirect (not popup). Chrome blocks third-party cookies which
    // makes the popup at qrprep.firebaseapp.com show blank white.
    // Redirect navigates the full page so no cross-origin cookie issues.
    try {
      const provider = new firebase.auth.GoogleAuthProvider();
      await auth.signInWithRedirect(provider);
    } catch (err) {
      console.error('[Auth] Google sign-in error:', err.code, err.message);
      if (err.code === 'auth/unauthorized-domain') {
        showDomainError();
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
      await auth.signInWithRedirect(provider);
    } catch (err) {
      console.error('[Auth] GitHub sign-in error:', err.code, err.message);
      if (err.code === 'auth/unauthorized-domain') {
        showDomainError();
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
    console.log('[Auth] saveStatus:', { id, status, hasUser: !!currentUser, hasDoc: !!userDoc, authSettled });

    // Always save to localStorage as fallback
    try {
      if (status) {
        localStorage.setItem('qr-prep-status-' + id, status);
      } else {
        localStorage.removeItem('qr-prep-status-' + id);
      }
    } catch (e) { /* ignore */ }

    if (!currentUser) {
      console.warn('[Auth] saveStatus: no currentUser, skipping Firestore');
      return;
    }

    const db = FirebaseConfig.getDb();
    if (!db) {
      console.warn('[Auth] saveStatus: no db instance');
      return;
    }

    // Wait for userDoc to be loaded if it's still pending (with timeout)
    if (!userDoc) {
      console.log('[Auth] userDoc not ready, waiting max 3s...');
      try {
        await Promise.race([
          waitForAuth(),
          new Promise((_, rej) => setTimeout(() => rej(new Error('auth-timeout')), 3000))
        ]);
      } catch (e) {
        console.warn('[Auth] waitForAuth:', e.message);
      }
    }

    // If still no userDoc, create a minimal one
    if (!userDoc) {
      console.warn('[Auth] Creating fallback userDoc');
      userDoc = {
        progress: {}, stats: { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } },
        xp: 0, level: 1, streak: { current: 0, longest: 0, lastActivityDate: null },
        favorites: [], collections: [], achievements: [],
      };
    }

    const previousStatus = userDoc.progress ? (userDoc.progress[id] || '') : '';

    try {
      const docRef = db.collection('users').doc(currentUser.uid);

      // Update local state IMMEDIATELY so UI reads the new status instantly
      if (!userDoc.progress) userDoc.progress = {};
      if (status) {
        userDoc.progress[id] = status;
      } else {
        delete userDoc.progress[id];
      }

      // Persist to Firestore: try update() first (reliable for nested paths),
      // fall back to set+merge if doc doesn't exist
      const writeProgress = async () => {
        try {
          if (status) {
            await docRef.update({ ['progress.' + id]: status });
          } else {
            await docRef.update({ ['progress.' + id]: firebase.firestore.FieldValue.delete() });
          }
          console.log('[Auth] Progress written (update)');
        } catch (err) {
          if (err.code === 'not-found') {
            console.log('[Auth] Doc not found, creating with set...');
            const data = { progress: {} };
            if (status) data.progress[id] = status;
            await docRef.set(data, { merge: true });
            console.log('[Auth] Progress written (set+merge)');
          } else {
            console.error('[Auth] Progress write error:', err.code, err.message);
          }
        }
      };
      writeProgress();

      // XP + stats tracking
      if (status === 'solved' && previousStatus !== 'solved') {
        const diff = getProblemDifficulty(id);
        const xpGain = XP_TABLE[diff] || 0;

        // Update stats locally first (instant UI update)
        if (!userDoc.stats) userDoc.stats = { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } };
        if (!userDoc.stats[diff]) userDoc.stats[diff] = { solved: 0, attempted: 0 };
        userDoc.stats[diff].solved++;

        // If previously attempted, decrement attempted count
        if (previousStatus === 'attempted' && userDoc.stats[diff].attempted > 0) {
          userDoc.stats[diff].attempted--;
        }

        // Update XP + level locally
        userDoc.xp = (userDoc.xp || 0) + xpGain;
        userDoc.level = calculateLevel(userDoc.xp).level;

        // Update streak locally
        updateStreak();

        // Dispatch event so dropdown XP updates immediately
        forceAuthUIUpdate();

        // Persist XP/stats to Firestore (background, non-blocking)
        const xpData = { stats: userDoc.stats, xp: userDoc.xp, level: userDoc.level, streak: userDoc.streak };
        docRef.update(xpData)
          .then(() => console.log('[Auth] XP/stats written'))
          .catch(err => {
            console.warn('[Auth] XP update() failed:', err.code, '- trying set+merge');
            return docRef.set(xpData, { merge: true });
          })
          .catch(err => console.error('[Auth] XP persist failed completely:', err));

        // Check achievements (non-blocking)
        if (typeof Achievements !== 'undefined') {
          try {
            const newBadges = Achievements.check(userDoc);
            for (const badge of newBadges) {
              Achievements.award(badge);
            }
          } catch (e) { console.warn('[Auth] Achievement check error:', e); }
        }
      } else if (status === 'attempted' && !previousStatus) {
        const diff = getProblemDifficulty(id);
        if (!userDoc.stats) userDoc.stats = { easy: { solved: 0, attempted: 0 }, medium: { solved: 0, attempted: 0 }, hard: { solved: 0, attempted: 0 } };
        if (!userDoc.stats[diff]) userDoc.stats[diff] = { solved: 0, attempted: 0 };
        userDoc.stats[diff].attempted++;
        docRef.update({ stats: userDoc.stats })
          .then(() => console.log('[Auth] Attempted stats written'))
          .catch(err => {
            return docRef.set({ stats: userDoc.stats }, { merge: true });
          })
          .catch(err => console.error('[Auth] Stats persist failed:', err));
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

  let problemDiffMap = null; // Map<id, difficulty> for O(1) lookup

  function getProblemDifficulty(id) {
    if (problemDiffMap) {
      return problemDiffMap.get(parseInt(id)) || 'medium';
    }
    if (!allProblems) return 'medium';
    const p = allProblems.find(prob => prob.id === parseInt(id));
    return p ? p.difficulty : 'medium';
  }

  function setProblemData(problems) {
    allProblems = problems;
    // Build O(1) lookup map
    problemDiffMap = new Map();
    for (const p of problems) {
      problemDiffMap.set(p.id, p.difficulty);
    }
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
    console.log('[Auth] toggleFavorite:', problemId, 'hasUser:', !!currentUser, 'hasDoc:', !!userDoc);
    if (!currentUser) return false;
    const db = FirebaseConfig.getDb();
    if (!db) return false;

    // Wait for userDoc if not ready yet (with timeout)
    if (!userDoc) {
      try {
        await Promise.race([
          waitForAuth(),
          new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 3000))
        ]);
      } catch (e) { console.warn('[Auth] toggleFavorite wait:', e.message); }
    }
    if (!userDoc) return false;

    const docRef = db.collection('users').doc(currentUser.uid);
    const id = parseInt(problemId);

    try {
      if (!userDoc.favorites) userDoc.favorites = [];

      if (userDoc.favorites.includes(id)) {
        // Update local state first
        userDoc.favorites = userDoc.favorites.filter(f => f !== id);
        // Persist: try update first, fallback to set+merge
        docRef.update({ favorites: firebase.firestore.FieldValue.arrayRemove(id) })
          .then(() => console.log('[Auth] Unfavorited persisted'))
          .catch(err => docRef.set({ favorites: firebase.firestore.FieldValue.arrayRemove(id) }, { merge: true }))
          .catch(err => console.error('[Auth] Unfavorite persist error:', err));
        return false;
      } else {
        // Update local state first
        userDoc.favorites.push(id);
        // Persist
        docRef.update({ favorites: firebase.firestore.FieldValue.arrayUnion(id) })
          .then(() => console.log('[Auth] Favorited persisted'))
          .catch(err => docRef.set({ favorites: firebase.firestore.FieldValue.arrayUnion(id) }, { merge: true }))
          .catch(err => console.error('[Auth] Favorite persist error:', err));

        // Check bookworm achievement
        if (typeof Achievements !== 'undefined') {
          try {
            const newBadges = Achievements.check(userDoc);
            for (const badge of newBadges) Achievements.award(badge);
          } catch (e) { /* ignore */ }
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
    if (!container || !currentUser) return;

    const photoURL = currentUser.photoURL || '';
    const name = currentUser.displayName || currentUser.email || 'User';
    const tier = getTier();
    const initial = name.charAt(0).toUpperCase();
    const levelInfo = calculateLevel(userDoc ? userDoc.xp : 0);
    const stats = userDoc?.stats || { easy: { solved: 0 }, medium: { solved: 0 }, hard: { solved: 0 } };
    const totalSolved = (stats.easy?.solved || 0) + (stats.medium?.solved || 0) + (stats.hard?.solved || 0);
    const streak = userDoc?.streak?.current || 0;
    const xp = userDoc?.xp || 0;

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
          <div class="nav__dd-profile-card">
            <div class="nav__dd-profile-top">
              ${photoURL
                ? `<img class="nav__dd-avatar" src="${photoURL}" alt="" referrerpolicy="no-referrer">`
                : `<span class="nav__dd-avatar nav__dd-avatar--initials">${initial}</span>`
              }
              <div class="nav__dd-info">
                <div class="nav__dd-name">${name}</div>
                <div class="nav__dd-email">${currentUser.email}</div>
              </div>
            </div>
            <div class="nav__dd-stats-row">
              <div class="nav__dd-stat">
                <span class="nav__dd-stat-val">${totalSolved}</span>
                <span class="nav__dd-stat-lbl">Solved</span>
              </div>
              <div class="nav__dd-stat">
                <span class="nav__dd-stat-val">${streak}</span>
                <span class="nav__dd-stat-lbl">Streak</span>
              </div>
              <div class="nav__dd-stat">
                <span class="nav__dd-stat-val">${xp}</span>
                <span class="nav__dd-stat-lbl">XP</span>
              </div>
            </div>
            <div class="nav__dd-xp-bar">
              <div class="nav__dd-xp-fill" style="width:${levelInfo.percent}%"></div>
            </div>
            <div class="nav__dd-xp-text">Level ${levelInfo.level} \u2022 ${levelInfo.currentXP}/${levelInfo.nextLevelXP} XP</div>
          </div>
          <div class="nav__dropdown-divider"></div>
          <a class="nav__dd-menu-item" href="profile.html">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            <span>My Profile</span>
          </a>
          <a class="nav__dd-menu-item" href="problems.html?filter=favorites">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
            <span>My Favorites</span>
          </a>
          <a class="nav__dd-menu-item" href="problems.html?status=solved">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
            <span>Solved Problems</span>
          </a>
          <div class="nav__dropdown-divider"></div>
          <button class="nav__dd-menu-item nav__dd-menu-item--danger" onclick="Auth.signOut()">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
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
    window.location.href = 'profile.html';
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

  // Expose XP lookup for toast messages
  function getProblemDifficultyXP(id) {
    const diff = getProblemDifficulty(id);
    return XP_TABLE[diff] || 0;
  }

  return {
    init, showAuthModal, signInWithGoogle, signInWithGitHub, signOut,
    saveStatus, getStatus, getTier,
    isLoggedIn, getUser, getUserDoc, waitForAuth,
    setProblemData, calculateLevel,
    toggleFavorite, isFavorited, getFavorites,
    renderLoginButton, renderUserUI,
    toggleDropdown, closeDropdown, showAccount,
    getProblemDifficultyXP,
  };
})();
