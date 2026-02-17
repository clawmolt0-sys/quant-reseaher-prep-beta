/* ============================================
   COLLECTIONS — User-created problem lists
   ============================================ */

const Collections = (() => {
  function getAll() {
    const doc = Auth.getUserDoc();
    return (doc && doc.collections) ? doc.collections : [];
  }

  async function create(name) {
    if (!Auth.isLoggedIn()) return null;
    const db = FirebaseConfig.getDb();
    if (!db) return null;

    // Wait for user doc if it's not ready yet
    let doc = Auth.getUserDoc();
    if (!doc) {
      try { await Auth.waitForAuth(); } catch (e) { /* timeout */ }
      doc = Auth.getUserDoc();
    }
    if (!doc) {
      console.error('[Collections] Cannot create — user doc not available');
      return null;
    }

    const newCollection = {
      id: 'col-' + Date.now(),
      name: name.trim(),
      problemIds: [],
      createdAt: new Date().toISOString(),
    };

    try {
      if (!doc.collections) doc.collections = [];
      doc.collections.push(newCollection);
      await db.collection('users').doc(Auth.getUser().uid).update({ collections: doc.collections });

      // Check organizer achievement
      if (typeof Achievements !== 'undefined') {
        try {
          const newBadges = Achievements.check(doc);
          for (const badge of newBadges) Achievements.award(badge);
        } catch (e) { /* ignore */ }
      }

      return newCollection;
    } catch (err) {
      console.error('[Collections] Create error:', err);
      return null;
    }
  }

  async function remove(collectionId) {
    if (!Auth.isLoggedIn()) return;
    const db = FirebaseConfig.getDb();
    if (!db) return;

    const doc = Auth.getUserDoc();
    if (!doc || !doc.collections) return;

    doc.collections = doc.collections.filter(c => c.id !== collectionId);
    try {
      await db.collection('users').doc(Auth.getUser().uid).update({ collections: doc.collections });
    } catch (err) {
      console.error('[Collections] Remove error:', err);
    }
  }

  async function addProblem(collectionId, problemId) {
    if (!Auth.isLoggedIn()) return;
    const db = FirebaseConfig.getDb();
    if (!db) return;

    let doc = Auth.getUserDoc();
    if (!doc) { try { await Auth.waitForAuth(); } catch (e) {} doc = Auth.getUserDoc(); }
    if (!doc || !doc.collections) return;

    const col = doc.collections.find(c => c.id === collectionId);
    if (!col) return;

    const id = parseInt(problemId);
    if (!col.problemIds.includes(id)) {
      col.problemIds.push(id);
      try {
        await db.collection('users').doc(Auth.getUser().uid).update({ collections: doc.collections });
      } catch (err) {
        console.error('[Collections] Add problem error:', err);
      }
    }
  }

  async function removeProblem(collectionId, problemId) {
    if (!Auth.isLoggedIn()) return;
    const db = FirebaseConfig.getDb();
    if (!db) return;

    let doc = Auth.getUserDoc();
    if (!doc) { try { await Auth.waitForAuth(); } catch (e) {} doc = Auth.getUserDoc(); }
    if (!doc || !doc.collections) return;

    const col = doc.collections.find(c => c.id === collectionId);
    if (!col) return;

    const id = parseInt(problemId);
    col.problemIds = col.problemIds.filter(pid => pid !== id);
    try {
      await db.collection('users').doc(Auth.getUser().uid).update({ collections: doc.collections });
    } catch (err) {
      console.error('[Collections] Remove problem error:', err);
    }
  }

  let currentModalProblemId = null;

  async function showModal(problemId) {
    const existing = document.querySelector('.collections-modal-overlay');
    if (existing) existing.remove();

    // Wait for userDoc if not ready
    if (!Auth.getUserDoc()) {
      try { await Auth.waitForAuth(); } catch (e) { /* timeout */ }
    }

    currentModalProblemId = parseInt(problemId);
    const collections = getAll();
    const id = currentModalProblemId;

    const overlay = document.createElement('div');
    overlay.className = 'collections-modal-overlay';
    overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };

    const items = collections.map(col => {
      const checked = col.problemIds.includes(id) ? 'checked' : '';
      return `
        <label class="collection-item">
          <input type="checkbox" ${checked} data-col-id="${col.id}" onchange="Collections._toggleProblem(this, ${id})">
          <span class="collection-item__name">${col.name}</span>
          <span class="collection-item__count">${col.problemIds.length} problems</span>
        </label>
      `;
    }).join('');

    overlay.innerHTML = `
      <div class="collections-modal">
        <div class="collections-modal__header">
          <h3>Save to List</h3>
          <button class="account-modal__close" onclick="this.closest('.collections-modal-overlay').remove()">&times;</button>
        </div>
        <div class="collections-modal__body">
          ${items || '<div style="color:var(--text-muted);font-size:var(--text-sm);padding:var(--space-4);text-align:center">No lists yet. Create one below!</div>'}
        </div>
        <div class="collections-modal__create">
          <input type="text" id="new-collection-name" class="collection-create__input" placeholder="New list name..." maxlength="40"
            onkeydown="if(event.key==='Enter'){Collections._createFromModal();event.preventDefault();}">
          <button class="btn btn--primary btn--sm" onclick="Collections._createFromModal()">Create</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    // Auto-focus the input
    setTimeout(() => {
      const input = document.getElementById('new-collection-name');
      if (input) input.focus();
    }, 100);
  }

  // Toast helper (reuse Problems.showToast if available)
  function _toast(msg) {
    if (typeof Problems !== 'undefined' && Problems.showToast) {
      // Not exposed yet, use inline toast
    }
    const existing = document.querySelector('.qr-toast');
    if (existing) existing.remove();
    const toast = document.createElement('div');
    toast.className = 'qr-toast';
    toast.textContent = msg;
    document.body.appendChild(toast);
    requestAnimationFrame(() => { toast.classList.add('qr-toast--show'); });
    setTimeout(() => {
      toast.classList.remove('qr-toast--show');
      setTimeout(() => toast.remove(), 300);
    }, 2500);
  }

  // Internal handlers (exposed for onclick)
  async function _toggleProblem(checkbox, problemId) {
    const colId = checkbox.getAttribute('data-col-id');
    const col = getAll().find(c => c.id === colId);
    if (checkbox.checked) {
      await addProblem(colId, problemId);
      _toast('Added to ' + (col ? col.name : 'list'));
    } else {
      await removeProblem(colId, problemId);
      _toast('Removed from ' + (col ? col.name : 'list'));
    }
    // Update count display
    const label = checkbox.closest('.collection-item');
    if (label) {
      const updatedCol = getAll().find(c => c.id === colId);
      const countEl = label.querySelector('.collection-item__count');
      if (updatedCol && countEl) countEl.textContent = updatedCol.problemIds.length + ' problems';
    }
  }

  async function _createFromModal() {
    const input = document.getElementById('new-collection-name');
    if (!input || !input.value.trim()) return;

    const name = input.value.trim();
    input.value = '';
    input.disabled = true;

    const col = await create(name);
    input.disabled = false;

    if (col) {
      _toast('List "' + name + '" created!');
      if (currentModalProblemId) {
        // Re-render the modal with the new collection
        showModal(currentModalProblemId);
      }
    } else {
      _toast('Failed to create list');
    }
  }

  return { getAll, create, remove, addProblem, removeProblem, showModal, _toggleProblem, _createFromModal };
})();
