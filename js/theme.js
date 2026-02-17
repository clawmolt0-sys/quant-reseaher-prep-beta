/* ============================================
   THEME — Dark/Light mode toggle
   ============================================ */

const Theme = (() => {
  const STORAGE_KEY = 'qr-prep-theme';
  let current = 'dark';

  function init() {
    // Read saved preference or default to dark
    current = localStorage.getItem(STORAGE_KEY) || 'dark';
    applyTheme(current);
    renderToggle();
  }

  function toggle() {
    current = current === 'dark' ? 'light' : 'dark';
    localStorage.setItem(STORAGE_KEY, current);
    applyTheme(current);
    renderToggle();
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
  }

  function getTheme() {
    return current;
  }

  function renderToggle() {
    const container = document.getElementById('theme-toggle-container');
    if (!container) return;

    const icon = current === 'dark' ? '\u2600\uFE0F' : '\uD83C\uDF19';
    const label = current === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';

    container.innerHTML = `
      <button class="theme-toggle" onclick="Theme.toggle()" aria-label="${label}" title="${label}">
        ${icon}
      </button>
    `;
  }

  return { init, toggle, getTheme };
})();
