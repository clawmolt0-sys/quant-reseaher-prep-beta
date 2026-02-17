/* ============================================
   AUTH — Firebase Authentication + Firestore
   Google OAuth, progress sync, tier management
   ============================================ */

const Auth = (() => {
  let currentUser = null;
  let userDoc = null;
  let migrated = false;

  // ---- Admin emails (always get pro tier) ----
  const ADMIN_EMAILS = [
    'alexwuyinchen@gmail.com',
  ];

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
        renderUserUI();
      } else {
        currentUser = null;
        userDoc = null;
        migrated = false;
        renderLoginButton();
      }
    });
  }

  // ---- Google Sign In ----
  async function signInWithGoogle() {
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
        // Popup blocked due to domain not being authorized — try redirect
        console.warn('[Auth] Popup blocked (unauthorized domain), trying redirect...');
        try {
          const provider = new firebase.auth.GoogleAuthProvider();
          await auth.signInWithRedirect(provider);
        } catch (redirectErr) {
          console.error('[Auth] Redirect sign in also failed:', redirectErr);
          showDomainError();
        }
      } else if (err.code === 'auth/popup-blocked') {
        // Browser blocked popup — try redirect
        const provider = new firebase.auth.GoogleAuthProvider();
        await auth.signInWithRedirect(provider);
      } else if (err.code !== 'auth/popup-closed-by-user') {
        console.error('[Auth] Sign in error:', err);
        alert('Sign in failed: ' + err.message);
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

  // ---- Firestore User Doc ----
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
        // Create new user doc
        const tier = isAdmin(user.email) ? 'pro' : 'free';
        userDoc = {
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
          tier: tier,
          joinDate: firebase.firestore.FieldValue.serverTimestamp(),
          progress: {},
        };
        await docRef.set(userDoc);
      }
    } catch (err) {
      console.error('[Auth] Error loading user doc:', err);
      userDoc = { tier: 'free', progress: {} };
    }
  }

  // ---- Migrate localStorage to Firestore ----
  async function migrateLocalStorage(uid) {
    const db = FirebaseConfig.getDb();
    if (!db) return;

    try {
      // Check if already migrated
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
        // Merge progress (don't overwrite existing cloud data)
        const existing = userDoc?.progress || {};
        const merged = { ...progress, ...existing }; // Cloud data takes priority
        await docRef.update({ progress: merged });
        userDoc.progress = merged;
        console.log('[Auth] Migrated', count, 'status entries to Firestore');
      }

      localStorage.setItem(migKey, 'true');
    } catch (err) {
      console.error('[Auth] Migration error:', err);
    }
  }

  // ---- Status Sync ----
  async function saveStatus(id, status) {
    // Always save to localStorage as fallback
    try {
      if (status) {
        localStorage.setItem('qr-prep-status-' + id, status);
      } else {
        localStorage.removeItem('qr-prep-status-' + id);
      }
    } catch (e) { /* ignore */ }

    // Save to Firestore if logged in
    if (!currentUser) return;

    const db = FirebaseConfig.getDb();
    if (!db) return;

    try {
      const docRef = db.collection('users').doc(currentUser.uid);
      if (status) {
        await docRef.update({ ['progress.' + id]: status });
        if (userDoc) userDoc.progress[id] = status;
      } else {
        await docRef.update({ ['progress.' + id]: firebase.firestore.FieldValue.delete() });
        if (userDoc) delete userDoc.progress[id];
      }
    } catch (err) {
      console.error('[Auth] Error saving status:', err);
    }
  }

  function getStatus(id) {
    // If logged in, prefer Firestore data
    if (currentUser && userDoc && userDoc.progress) {
      return userDoc.progress[id] || '';
    }
    // Fallback to localStorage
    try { return localStorage.getItem('qr-prep-status-' + id) || ''; }
    catch (e) { return ''; }
  }

  // ---- Tier ----
  function getTier() {
    // Admins always get pro
    if (currentUser && isAdmin(currentUser.email)) return 'pro';
    if (!currentUser || !userDoc) return 'free';
    return userDoc.tier || 'free';
  }

  function isLoggedIn() {
    return !!currentUser;
  }

  function getUser() {
    return currentUser;
  }

  function getUserDoc() {
    return userDoc;
  }

  // ---- UI: Login Button ----
  function renderLoginButton() {
    const container = document.getElementById('auth-container');
    if (!container) return;

    container.innerHTML = `
      <button class="nav__auth-btn" onclick="Auth.signInWithGoogle()">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
          <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
          <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18A10.96 10.96 0 001 12c0 1.77.42 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
          <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
        </svg>
        <span>Sign In</span>
      </button>
    `;
  }

  // ---- UI: Logged-in User ----
  function renderUserUI() {
    const container = document.getElementById('auth-container');
    if (!container) return;

    const photoURL = currentUser.photoURL || '';
    const name = currentUser.displayName || currentUser.email || 'User';
    const tier = getTier();
    const initial = name.charAt(0).toUpperCase();

    container.innerHTML = `
      <div class="nav__user-menu">
        <button class="nav__user-btn" onclick="Auth.toggleDropdown()">
          ${photoURL
            ? `<img class="nav__user-avatar" src="${photoURL}" alt="${name}" referrerpolicy="no-referrer">`
            : `<span class="nav__user-avatar nav__user-avatar--initials">${initial}</span>`
          }
          <span class="nav__user-name">${name.split(' ')[0]}</span>
          <span class="tier-badge tier-badge--${tier}">${tier}</span>
        </button>
        <div class="nav__user-dropdown" id="user-dropdown">
          <div class="nav__dropdown-header">
            <span class="nav__dropdown-name">${name}</span>
            <span class="nav__dropdown-email">${currentUser.email}</span>
          </div>
          <div class="nav__dropdown-divider"></div>
          <button class="nav__dropdown-item" onclick="Auth.showAccount()">
            <span>Profile & Stats</span>
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

    // Close on outside click
    if (dd.classList.contains('nav__user-dropdown--open')) {
      setTimeout(() => {
        document.addEventListener('click', closeDropdownOnOutside);
      }, 0);
    }
  }

  function closeDropdownOnOutside(e) {
    const menu = document.querySelector('.nav__user-menu');
    if (menu && !menu.contains(e.target)) {
      closeDropdown();
    }
  }

  function closeDropdown() {
    const dd = document.getElementById('user-dropdown');
    if (dd) dd.classList.remove('nav__user-dropdown--open');
    document.removeEventListener('click', closeDropdownOnOutside);
  }

  // ---- Account Modal ----
  function showAccount() {
    closeDropdown();

    if (!currentUser || !userDoc) return;

    const progress = userDoc.progress || {};
    const solved = Object.values(progress).filter(v => v === 'solved').length;
    const attempted = Object.values(progress).filter(v => v === 'attempted').length;
    const total = solved + attempted;
    const tier = getTier();
    const joinDate = userDoc.joinDate
      ? (userDoc.joinDate.toDate ? userDoc.joinDate.toDate().toLocaleDateString() : new Date(userDoc.joinDate).toLocaleDateString())
      : 'Recently';

    const overlay = document.createElement('div');
    overlay.className = 'account-modal-overlay';
    overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };

    overlay.innerHTML = `
      <div class="account-modal">
        <button class="account-modal__close" onclick="this.closest('.account-modal-overlay').remove()">&times;</button>

        <div class="account-modal__header">
          ${currentUser.photoURL
            ? `<img class="account-modal__avatar" src="${currentUser.photoURL}" alt="" referrerpolicy="no-referrer">`
            : `<span class="account-modal__avatar account-modal__avatar--initials">${(currentUser.displayName || 'U').charAt(0)}</span>`
          }
          <div class="account-modal__info">
            <div class="account-modal__name">${currentUser.displayName || 'User'}</div>
            <div class="account-modal__email">${currentUser.email}</div>
            <span class="tier-badge tier-badge--${tier}" style="margin-top:4px">${tier === 'pro' ? 'Pro' : 'Free'} Plan</span>
          </div>
        </div>

        <div class="account-modal__stats">
          <div class="account-stat">
            <div class="account-stat__number">${solved}</div>
            <div class="account-stat__label">Solved</div>
          </div>
          <div class="account-stat">
            <div class="account-stat__number">${attempted}</div>
            <div class="account-stat__label">Attempted</div>
          </div>
          <div class="account-stat">
            <div class="account-stat__number">${total}</div>
            <div class="account-stat__label">Total</div>
          </div>
        </div>

        <div class="account-modal__meta">
          <div class="account-modal__meta-item">
            <span class="account-modal__meta-label">Member since</span>
            <span class="account-modal__meta-value">${joinDate}</span>
          </div>
        </div>

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
    init, signInWithGoogle, signOut,
    saveStatus, getStatus, getTier,
    isLoggedIn, getUser, getUserDoc,
    renderLoginButton, renderUserUI,
    toggleDropdown, closeDropdown, showAccount,
  };
})();
