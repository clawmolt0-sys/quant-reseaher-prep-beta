/* ============================================
   LABS — Code labs list (Phase 3 placeholder)
   ============================================ */

const Labs = (() => {
  async function init() {
    const labs = (await DataLoader.labs()) || [];
    const topicsData = (await DataLoader.topics()) || { tracks: [] };

    const container = document.getElementById('content');
    if (!container) return;

    function getTopicTitle(topicId) {
      for (const track of topicsData.tracks) {
        const t = track.topics.find(t => t.id === topicId);
        if (t) return t.title;
      }
      return topicId;
    }

    container.innerHTML = `
      <div class="container">
        <div class="section-header">
          <h1 class="section-header__title">Code Labs</h1>
          <p class="section-header__subtitle">Hands-on coding exercises with real financial data. Write code, analyze data, and build quant skills.</p>
        </div>

        <div class="grid-2">
          ${labs.map(lab => `
            <div class="card">
              <div style="display:flex; justify-content:space-between; align-items:start; margin-bottom:var(--space-3)">
                <h3 class="card__title">${lab.title}</h3>
                ${lab.status === 'coming-soon'
                  ? '<span class="coming-soon">🚧 Coming Soon</span>'
                  : App.difficultyBadge(lab.difficulty)
                }
              </div>
              <p class="card__description">${lab.description}</p>
              <div class="card__meta">
                <span class="tag tag--topic">${getTopicTitle(lab.topic)}</span>
                ${App.difficultyBadge(lab.difficulty)}
                ${lab.estimated_minutes ? `<span style="font-size:var(--text-xs);color:var(--text-muted)">~${lab.estimated_minutes} min</span>` : ''}
              </div>
              <div style="margin-top:var(--space-3); display:flex; flex-wrap:wrap; gap:var(--space-1)">
                ${lab.concepts.map(c => `<span class="tag" style="font-size:10px">${c}</span>`).join('')}
              </div>
            </div>
          `).join('')}
        </div>

        <div style="text-align:center; margin-top:var(--space-12); padding:var(--space-8); background:var(--bg-card); border-radius:var(--radius-lg); border:1px solid var(--border-color)">
          <h3 style="font-size:var(--text-xl); margin-bottom:var(--space-3)">Interactive Labs Coming Soon</h3>
          <p style="color:var(--text-secondary); max-width:500px; margin:0 auto; line-height:1.6;">
            Code labs will feature an in-browser Python editor, real financial datasets,
            and an AI assistant to help you work through problems step by step.
          </p>
        </div>
      </div>
    `;
  }

  return { init };
})();
