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

    const doc = Auth.getUserDoc();
    if (!doc) return null;

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
        const newBadges = Achievements.check(doc);
        for (const badge of newBadges) await Achievements.award(badge);
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

    const doc = Auth.getUserDoc();
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

    const doc = Auth.getUserDoc();
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

  function showModal(problemId) {
    const existing = document.querySelector('.collections-modal-overlay');
    if (existing) existing.remove();

    const collections = getAll();
    const id = parseInt(problemId);

    const overlay = document.createElement('div');
    overlay.className = 'collections-modal-overlay';
    overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };

    const items = collections.map(col => {
      const checked = col.problemIds.includes(id) ? 'checked' : '';
      return `
        <label class="collection-item">
          <input type="checkbox" ${checked} data-col-id="${col.id}" onchange="Collections._toggleProblem(this, ${id})">
          <span class="collection-item__name">${col.name}</span>
          <span class="collection-item__count">${col.problemIds.length}</span>
        </label>
      `;
    }).join('');

    overlay.innerHTML = `
      <div class="collections-modal">
        <div class="collections-modal__header">
          <h3>Add to Collection</h3>
          <button class="account-modal__close" onclick="this.closest('.collections-modal-overlay').remove()">&times;</button>
        </div>
        <div class="collections-modal__body">
          ${items || '<div style="color:var(--text-muted);font-size:var(--text-sm);padding:var(--space-4);text-align:center">No collections yet. Create one below!</div>'}
        </div>
        <div class="collections-modal__create">
          <input type="text" id="new-collection-name" class="collection-create__input" placeholder="New collection name..." maxlength="40">
          <button class="btn btn--primary btn--sm" onclick="Collections._createFromModal()">Create</button>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
  }

  // Internal handlers (exposed for onclick)
  async function _toggleProblem(checkbox, problemId) {
    const colId = checkbox.getAttribute('data-col-id');
    if (checkbox.checked) {
      await addProblem(colId, problemId);
    } else {
      await removeProblem(colId, problemId);
    }
  }

  async function _createFromModal() {
    const input = document.getElementById('new-collection-name');
    if (!input || !input.value.trim()) return;

    const col = await create(input.value);
    if (col) {
      // Re-render modal
      const overlay = document.querySelector('.collections-modal-overlay');
      if (overlay) {
        // Get the problemId from the modal context
        overlay.remove();
      }
    }
  }

  return { getAll, create, remove, addProblem, removeProblem, showModal, _toggleProblem, _createFromModal };
})();
