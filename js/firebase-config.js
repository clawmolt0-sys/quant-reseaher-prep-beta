/* ============================================
   FIREBASE CONFIG — App initialization
   ============================================

   To set up Firebase:
   1. Go to https://console.firebase.google.com
   2. Create a new project (e.g. "qr-prep")
   3. Add a Web app
   4. Copy the config object below
   5. Enable Authentication > Sign-in method > Google
   6. Enable Cloud Firestore (start in test mode)
   7. Add your GitHub Pages domain to Authorized domains
   ============================================ */

const FirebaseConfig = (() => {
  const config = {
    apiKey: "AIzaSyDGlaIXU9u0RwWoepLR45hJGlpIOREbQ1A",
    authDomain: "qrprep.firebaseapp.com",
    projectId: "qrprep",
    storageBucket: "qrprep.firebasestorage.app",
    messagingSenderId: "269729809695",
    appId: "1:269729809695:web:4379017f0e6bec69e7dc2a",
    measurementId: "G-7BG34QV7TV"
  };

  let initialized = false;

  function init() {
    if (initialized) return;
    try {
      if (typeof firebase === 'undefined') {
        console.warn('[FirebaseConfig] Firebase SDK not loaded');
        return;
      }

      if (config.apiKey === 'YOUR_API_KEY') {
        console.warn('[FirebaseConfig] Firebase not configured. Auth features disabled.');
        return;
      }

      firebase.initializeApp(config);

      // Force long polling — WebSocket connections can silently fail on
      // GitHub Pages / some corporate networks, causing writes to hang.
      firebase.firestore().settings({
        experimentalForceLongPolling: true,
        merge: true
      });

      // NOTE: We intentionally do NOT enable Firestore offline persistence.
      // enablePersistence() creates IndexedDB caches that on GitHub Pages
      // frequently enter a broken "offline" state.

      // Fire-and-forget cleanup of stale IndexedDB from old persistence
      try {
        if (typeof indexedDB !== 'undefined' && indexedDB.databases) {
          indexedDB.databases().then(dbs => {
            for (const db of dbs) {
              if (db.name && (db.name.startsWith('firestore') || db.name.startsWith('firebase-'))) {
                indexedDB.deleteDatabase(db.name);
                console.log('[FirebaseConfig] Cleaned stale IndexedDB:', db.name);
              }
            }
          }).catch(() => {});
        }
      } catch (e) { /* ignore */ }

      initialized = true;
      console.log('[FirebaseConfig] Initialized (long-polling mode)');
    } catch (err) {
      console.error('[FirebaseConfig] Init error:', err);
    }
  }

  function isConfigured() {
    return config.apiKey !== 'YOUR_API_KEY';
  }

  function isInitialized() {
    return initialized;
  }

  function getAuth() {
    if (!initialized) return null;
    return firebase.auth();
  }

  function getDb() {
    if (!initialized) return null;
    return firebase.firestore();
  }

  return { init, isConfigured, isInitialized, getAuth, getDb };
})();
