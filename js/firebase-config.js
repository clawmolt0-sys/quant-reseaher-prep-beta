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
  let initPromise = null; // so multiple callers can await the same init

  // Clean up stale Firestore IndexedDB BEFORE initializing Firebase.
  // Old enablePersistence() created IndexedDB caches that put the SDK
  // in a permanent "offline" state where all reads/writes hang forever.
  async function cleanStaleIndexedDB() {
    try {
      if (typeof indexedDB === 'undefined') return;

      // Always try cleanup (not gated by localStorage flag) because
      // the previous async fire-and-forget version may not have run.
      if (indexedDB.databases) {
        const dbs = await indexedDB.databases();
        for (const db of dbs) {
          if (db.name && (db.name.startsWith('firestore') || db.name.startsWith('firebase'))) {
            try {
              indexedDB.deleteDatabase(db.name);
              console.log('[FirebaseConfig] Deleted stale IndexedDB:', db.name);
            } catch (e) { /* ignore individual delete errors */ }
          }
        }
      } else {
        // Fallback for browsers without indexedDB.databases() (Firefox < 126)
        // Try common Firestore IndexedDB names
        const commonNames = [
          'firestore/[DEFAULT]/qrprep/main',
          'firestore/[DEFAULT]/qrprep',
          'firebase-heartbeat-database',
          'firebase-installations-database',
        ];
        for (const name of commonNames) {
          try { indexedDB.deleteDatabase(name); } catch (e) { /* ignore */ }
        }
      }
    } catch (e) {
      console.warn('[FirebaseConfig] IndexedDB cleanup error (non-fatal):', e);
    }
  }

  async function init() {
    if (initialized) return;

    // If init is already in progress, return the existing promise
    if (initPromise) return initPromise;

    initPromise = (async () => {
      try {
        // Check if Firebase SDK is loaded
        if (typeof firebase === 'undefined') {
          console.warn('[FirebaseConfig] Firebase SDK not loaded');
          return;
        }

        // Check if config has been set
        if (config.apiKey === 'YOUR_API_KEY') {
          console.warn('[FirebaseConfig] Firebase not configured. Auth features disabled.');
          return;
        }

        // CRITICAL: Clean IndexedDB BEFORE Firebase init to prevent
        // the Firestore SDK from detecting old persistence caches
        await cleanStaleIndexedDB();

        firebase.initializeApp(config);

        // NOTE: We intentionally do NOT enable Firestore offline persistence.
        // enablePersistence() creates an IndexedDB cache that on GitHub Pages
        // frequently enters a broken "offline" state, causing all reads/writes
        // to fail with "unavailable - client is offline" errors.

        // Force long polling to avoid WebSocket issues on some networks/hosts
        firebase.firestore().settings({
          experimentalForceLongPolling: true,
          merge: true
        });

        initialized = true;
        console.log('[FirebaseConfig] Initialized successfully (long-polling mode)');
      } catch (err) {
        console.error('[FirebaseConfig] Init error:', err);
      }
    })();

    return initPromise;
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
