/* ============================================
   LABS — Code labs list (Phase 3 placeholder)
   ============================================ */

const Labs = (() => {
  async function init() {
    const container = document.getElementById('content');
    if (!container) return;

    // Show Coming Soon page
    container.innerHTML = `
      <div class="container" style="max-width:800px">
        <div class="coming-soon-hero">
          <div class="coming-soon-hero__icon">
            <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>
            </svg>
          </div>
          <h1 class="coming-soon-hero__title">Code Labs</h1>
          <p class="coming-soon-hero__subtitle">Hands-on coding exercises with real financial data, an in-browser Python editor, and AI-assisted learning.</p>
          <div class="coming-soon-hero__badge">\u{1F6A7} Coming Soon</div>
          <p class="coming-soon-hero__desc">
            Code labs will let you practice quantitative finance concepts with real datasets.
            Build Monte Carlo simulations, optimize portfolios, model volatility, and more \u2014 all in your browser.
          </p>
          <div class="coming-soon-hero__preview">
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F4BB}</div>
              <div class="coming-soon-card__text">Python Editor</div>
            </div>
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F4CA}</div>
              <div class="coming-soon-card__text">Financial Data</div>
            </div>
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F916}</div>
              <div class="coming-soon-card__text">AI Assistant</div>
            </div>
          </div>
          <a href="problems.html" class="btn btn--primary" style="margin-top:var(--space-6)">Browse All Problems \u2192</a>
        </div>
      </div>
    `;
  }

  return { init };
})();
