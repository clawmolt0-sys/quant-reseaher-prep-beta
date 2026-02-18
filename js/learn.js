/* ============================================
   LEARN — Learning path rendering
   ============================================ */

const Learn = (() => {
  let topicsData = null;
  let lecturesData = [];

  async function init() {
    const container = document.getElementById('content');
    if (!container) return;

    // Show Coming Soon page
    container.innerHTML = `
      <div class="container" style="max-width:800px">
        <div class="coming-soon-hero">
          <div class="coming-soon-hero__icon">
            <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/>
              <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>
            </svg>
          </div>
          <h1 class="coming-soon-hero__title">Learning Path</h1>
          <p class="coming-soon-hero__subtitle">Structured lectures covering probability, statistics, stochastic calculus, and quantitative finance.</p>
          <div class="coming-soon-hero__badge">\u{1F6A7} Coming Soon</div>
          <p class="coming-soon-hero__desc">
            We\u2019re building a comprehensive learning experience with two tracks: Core Foundations and
            Applied Quant Finance. Each track includes lectures, practice problems, and interactive exercises.
          </p>
          <div class="coming-soon-hero__preview">
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F4D0}</div>
              <div class="coming-soon-card__text">Core Foundations</div>
            </div>
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F4C8}</div>
              <div class="coming-soon-card__text">Applied Quant</div>
            </div>
            <div class="coming-soon-card coming-soon-card--disabled">
              <div class="coming-soon-card__icon">\u{1F393}</div>
              <div class="coming-soon-card__text">Practice Tracks</div>
            </div>
          </div>
          <a href="problems.html" class="btn btn--primary" style="margin-top:var(--space-6)">Browse All Problems \u2192</a>
        </div>
      </div>
    `;
  }

  // ---- Landing Page (no params) ----
  function renderLandingPage() {
    const container = document.getElementById('content');
    if (!container) return;

    container.innerHTML = `
      <div class="container">
        <div class="section-header">
          <h1 class="section-header__title">Learning Path</h1>
          <p class="section-header__subtitle">Systematic preparation organized into two tracks. Follow the lectures in order or jump to any topic.</p>
        </div>

        <div class="track-cards">
          ${topicsData.tracks.map(track => {
            const lectureCount = lecturesData.filter(l => l.track === track.id).length;
            return `
              <a class="track-card" href="learn.html?track=${track.id}">
                <div class="track-card__icon">${track.icon}</div>
                <h2 class="track-card__title">${track.title}</h2>
                <p class="track-card__description">${track.description}</p>
                <div class="track-card__topics">
                  ${track.topics.map(t => `<span class="tag">${t.title}</span>`).join('')}
                </div>
                <div style="margin-top: var(--space-4); font-size: var(--text-sm); color: var(--accent); font-weight: 600;">
                  ${track.topics.length} topics &middot; ${lectureCount} lectures
                </div>
              </a>
            `;
          }).join('')}
        </div>
      </div>
    `;
  }

  // ---- Track Overview ----
  function renderTrackOverview(trackId) {
    const container = document.getElementById('content');
    if (!container) return;

    const track = topicsData.tracks.find(t => t.id === trackId);
    if (!track) {
      container.innerHTML = `<div class="container"><p>Track not found.</p></div>`;
      return;
    }

    container.innerHTML = `
      <div class="container">
        <div class="breadcrumbs">
          <a href="learn.html">Learn</a>
          <span class="breadcrumbs__sep"></span>
          <span>${track.title}</span>
        </div>

        <div class="track-overview">
          <h1 class="track-overview__title">${track.icon} ${track.title}</h1>
          <p class="track-overview__description">${track.description}</p>

          <div class="track-topics-grid">
            ${track.topics.map(topic => {
              const lectures = lecturesData.filter(l => l.track === trackId && l.topic === topic.id);
              return `
                <a class="track-topic-card" href="learn.html?track=${trackId}&topic=${topic.id}">
                  <div class="track-topic-card__order">Module ${topic.order}</div>
                  <h3 class="track-topic-card__title">${topic.title}</h3>
                  <p class="track-topic-card__description">${topic.description}</p>
                  <div class="track-topic-card__stat">
                    ${lectures.length} lecture${lectures.length !== 1 ? 's' : ''}
                    ${lectures.length === 0 ? ' &middot; Coming soon' : ''}
                  </div>
                </a>
              `;
            }).join('')}
          </div>
        </div>
      </div>
    `;
  }

  // ---- Topic Page (with sidebar) ----
  function renderTopicPage(trackId, topicId) {
    const container = document.getElementById('content');
    if (!container) return;

    const track = topicsData.tracks.find(t => t.id === trackId);
    if (!track) return;
    const topic = track.topics.find(t => t.id === topicId);
    if (!topic) return;

    const lectures = lecturesData
      .filter(l => l.track === trackId && l.topic === topicId && l.type !== 'slides')
      .sort((a, b) => a.order - b.order);

    container.innerHTML = `
      <div class="page-with-sidebar">
        ${buildSidebar(trackId, topicId)}

        <div class="topic-content">
          <div class="breadcrumbs">
            <a href="learn.html">Learn</a>
            <span class="breadcrumbs__sep"></span>
            <a href="learn.html?track=${trackId}">${track.title}</a>
            <span class="breadcrumbs__sep"></span>
            <span>${topic.title}</span>
          </div>

          <div class="topic-header">
            <h1 class="topic-header__title">${topic.title}</h1>
            <p class="topic-header__description">${topic.description}</p>
            <div class="topic-header__meta">
              <span>${lectures.length} lecture${lectures.length !== 1 ? 's' : ''}</span>
            </div>
          </div>

          ${lectures.length > 0 ? `
            <div class="lecture-list">
              ${lectures.map(lec => `
                <div class="lecture-card" onclick="window.location='learn.html?track=${trackId}&topic=${topicId}&lecture=${lec.id}'">
                  <div class="lecture-card__order">${lec.order}</div>
                  <div class="lecture-card__info">
                    <div class="lecture-card__title">${lec.title}</div>
                    <div class="lecture-card__description">${lec.description}</div>
                    <div class="lecture-card__meta">
                      <span>${getLecTypeLabel(lec)}</span>
                      ${lec.duration_minutes ? `<span>&middot; ${lec.duration_minutes} min</span>` : ''}
                    </div>
                  </div>
                </div>
              `).join('')}
            </div>
          ` : `
            <div class="empty-state">
              <div class="empty-state__icon">&#128218;</div>
              <div class="empty-state__title">Content coming soon</div>
              <p>Lectures for this topic are being prepared.</p>
            </div>
          `}
        </div>
      </div>
    `;
  }

  function getLecTypeLabel(lec) {
    if (lec.type === 'notebook') return '&#128211; Interactive Notebook';
    if (lec.type === 'slides') return '&#128196; Slides';
    return '&#128218; Content';
  }

  // ---- Lecture Viewer ----
  function renderLectureViewer(lectureId, trackId, topicId) {
    const container = document.getElementById('content');
    if (!container) return;

    const lecture = lecturesData.find(l => l.id === lectureId);
    if (!lecture) {
      container.innerHTML = `<div class="container"><p>Lecture not found.</p></div>`;
      return;
    }

    const track = topicsData.tracks.find(t => t.id === (trackId || lecture.track));
    const topic = track?.topics.find(t => t.id === (topicId || lecture.topic));

    const trackLectures = lecturesData
      .filter(l => l.track === lecture.track && l.topic === lecture.topic)
      .sort((a, b) => a.order - b.order);
    const currentIdx = trackLectures.findIndex(l => l.id === lectureId);
    const prev = currentIdx > 0 ? trackLectures[currentIdx - 1] : null;
    const next = currentIdx < trackLectures.length - 1 ? trackLectures[currentIdx + 1] : null;

    container.innerHTML = `
      <div class="page-with-sidebar">
        ${buildSidebar(lecture.track, lecture.topic)}

        <div class="topic-content">
          <div class="breadcrumbs">
            <a href="learn.html">Learn</a>
            <span class="breadcrumbs__sep"></span>
            <a href="learn.html?track=${lecture.track}">${track?.title || ''}</a>
            <span class="breadcrumbs__sep"></span>
            <a href="learn.html?track=${lecture.track}&topic=${lecture.topic}">${topic?.title || ''}</a>
            <span class="breadcrumbs__sep"></span>
            <span>${lecture.title}</span>
          </div>

          <div class="lecture-viewer">
            <div class="lecture-viewer__header">
              <h1 class="lecture-viewer__title">${lecture.title}</h1>
              <div style="display:flex; gap:var(--space-2); align-items:center; flex-wrap:wrap;">
                <span class="tag">${getLecTypeLabel(lecture)}</span>
                ${lecture.duration_minutes ? `<span style="font-size:var(--text-xs); color:var(--text-muted)">${lecture.duration_minutes} min</span>` : ''}
              </div>
            </div>
            <div class="lecture-viewer__content" id="lecture-content">
              <div class="nb-loading">
                <div style="font-size:2rem">&#9881;</div>
                <div style="color:var(--text-muted);font-size:var(--text-sm)">Loading lecture...</div>
              </div>
            </div>
          </div>

          <div style="display:flex; justify-content:space-between; margin-top:var(--space-4)">
            ${prev
              ? `<a class="btn btn--ghost" href="learn.html?track=${lecture.track}&topic=${lecture.topic}&lecture=${prev.id}">&larr; ${prev.title}</a>`
              : '<span></span>'
            }
            ${next
              ? `<a class="btn btn--ghost" href="learn.html?track=${lecture.track}&topic=${lecture.topic}&lecture=${next.id}">${next.title} &rarr;</a>`
              : '<span></span>'
            }
          </div>
        </div>
      </div>
    `;

    // Load content based on type
    loadLectureContent(lecture);
  }

  async function loadLectureContent(lecture) {
    const el = document.getElementById('lecture-content');
    if (!el) return;

    if (lecture.type === 'notebook' && lecture.source) {
      // Use the notebook renderer to render .ipynb directly
      await NotebookRenderer.render(lecture.source, el);
    } else if (lecture.type === 'slides') {
      // Slides content placeholder
      el.innerHTML = `
        <div class="empty-state" style="min-height:300px">
          <div class="empty-state__icon">&#128196;</div>
          <div class="empty-state__title">Content coming soon</div>
          <p>Slide-based content for this lecture is being prepared.</p>
        </div>
      `;
    } else {
      el.innerHTML = `
        <div class="empty-state" style="min-height:300px">
          <div class="empty-state__icon">&#128218;</div>
          <div class="empty-state__title">Content will be available soon</div>
        </div>
      `;
    }
  }

  // ---- Sidebar builder ----
  function buildSidebar(activeTrack, activeTopic) {
    return `
      <nav class="sidebar">
        ${topicsData.tracks.map(track => `
          <div class="sidebar__section">
            <div class="sidebar__section-title">${track.title}</div>
            <ul class="topic-list">
              ${track.topics.map(topic => `
                <li class="topic-list__item">
                  <a class="topic-list__link ${track.id === activeTrack && topic.id === activeTopic ? 'topic-list__link--active' : ''}"
                     href="learn.html?track=${track.id}&topic=${topic.id}">
                    <span class="topic-list__order">${topic.order}.</span>
                    ${topic.title}
                  </a>
                </li>
              `).join('')}
            </ul>
          </div>
        `).join('')}
      </nav>
    `;
  }

  return { init };
})();
