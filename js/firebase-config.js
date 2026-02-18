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

      // ALWAYS delete firebaseLocalStorageDb BEFORE Firebase init.
      // Firebase Auth with LOCAL persistence uses this IndexedDB to store sessions.
      // If it's corrupted (from old enablePersistence()), onAuthStateChanged hangs forever.
      // We use SESSION persistence (sessionStorage) instead, so this DB is never needed.
      // Delete it on EVERY page load to prevent it from causing hangs.
      try {
        indexedDB.deleteDatabase('firebaseLocalStorageDb');
        console.log('[FirebaseConfig] Deleted firebaseLocalStorageDb');
      } catch (e) { /* ignore */ }
      // Clean other old Firestore IndexedDB databases (one-time)
      if (!sessionStorage.getItem('qr-idb-fix-v3')) {
        try {
          indexedDB.deleteDatabase('firestore/[DEFAULT]/qrprep/main');
          indexedDB.deleteDatabase('firestore/[DEFAULT]/qrprep');
          indexedDB.deleteDatabase('firebase-heartbeat-database');
          indexedDB.deleteDatabase('firebase-installations-database');
        } catch (e) { /* ignore */ }
        sessionStorage.setItem('qr-idb-fix-v3', '1');
      }

      // Initialize or get existing app
      if (!firebase.apps.length) {
        firebase.initializeApp(config);
      }

      // Apply Firestore settings — disable autoDetect when forcing long polling
      try {
        firebase.firestore().settings({
          experimentalForceLongPolling: true,
          experimentalAutoDetectLongPolling: false,
          merge: true
        });
      } catch (settingsErr) {
        // Already applied or Firestore already accessed
        console.log('[FirebaseConfig] Firestore settings:', settingsErr.message);
      }

      initialized = true;
      console.log('[FirebaseConfig] Initialized');
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
