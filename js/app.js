/* ============================================
   APP — Shared initialization, nav, routing
   ============================================ */

const App = (() => {
  // Get current page name from URL
  function getCurrentPage() {
    const path = window.location.pathname;
    const file = path.split('/').pop() || 'index.html';
    return file.replace('.html', '');
  }

  // Get query params as object
  function getParams() {
    return Object.fromEntries(new URLSearchParams(window.location.search));
  }

  // Set query params without reload
  function setParams(params) {
    const url = new URL(window.location);
    Object.entries(params).forEach(([k, v]) => {
      if (v === null || v === undefined || v === '') {
        url.searchParams.delete(k);
      } else {
        url.searchParams.set(k, v);
      }
    });
    window.history.pushState({}, '', url);
  }

  // Highlight active nav link
  function initNav() {
    const page = getCurrentPage();
    document.querySelectorAll('.nav__link').forEach(link => {
      const href = link.getAttribute('href');
      const linkPage = href.replace('.html', '').replace('./', '');
      if (linkPage === page || (page === 'index' && linkPage === '')) {
        link.classList.add('nav__link--active');
      }
    });

    // Mobile menu toggle
    const toggle = document.querySelector('.nav__mobile-toggle');
    const links = document.querySelector('.nav__links');
    if (toggle && links) {
      toggle.addEventListener('click', () => {
        links.classList.toggle('nav__links--open');
      });
    }
  }

  // Create reusable HTML for a difficulty badge
  function difficultyBadge(difficulty) {
    return `<span class="badge badge--${difficulty}">${difficulty}</span>`;
  }

  // Create a topic tag
  function topicTag(topicId, topicTitle) {
    return `<a class="tag tag--topic" href="problems.html?topic=${topicId}">${topicTitle || topicId}</a>`;
  }

  // Create a company tag
  function companyTag(companyId, companyName) {
    return `<a class="tag tag--company" href="problems.html?company=${companyId}">${companyName || companyId}</a>`;
  }

  // Lookup topic title from topics data
  async function getTopicTitle(topicId) {
    const data = await DataLoader.topics();
    if (!data) return topicId;
    for (const track of data.tracks) {
      const topic = track.topics.find(t => t.id === topicId);
      if (topic) return topic.title;
    }
    return topicId;
  }

  // Lookup company name
  async function getCompanyName(companyId) {
    const companies = await DataLoader.companies();
    if (!companies) return companyId;
    const company = companies.find(c => c.id === companyId);
    return company ? company.name : companyId;
  }

  // Escape HTML
  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // Init
  document.addEventListener('DOMContentLoaded', () => {
    initNav();
    // Initialize Theme if available
    if (typeof Theme !== 'undefined') {
      Theme.init();
    }
    // Initialize Auth if available
    if (typeof Auth !== 'undefined') {
      Auth.init();
    }
  });

  return {
    getCurrentPage,
    getParams,
    setParams,
    difficultyBadge,
    topicTag,
    companyTag,
    getTopicTitle,
    getCompanyName,
    escapeHtml,
  };
})();
