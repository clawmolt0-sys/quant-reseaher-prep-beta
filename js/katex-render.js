/* ============================================
   KATEX RENDER — Auto-render LaTeX on page
   ============================================ */

const KatexRender = (() => {
  function renderMath(el) {
    if (typeof renderMathInElement === 'function') {
      renderMathInElement(el || document.body, {
        delimiters: [
          { left: '$$', right: '$$', display: true },
          { left: '$', right: '$', display: false },
          { left: '\\(', right: '\\)', display: false },
          { left: '\\[', right: '\\]', display: true },
        ],
        throwOnError: false,
      });
    }
  }

  // Render on page load
  document.addEventListener('DOMContentLoaded', () => {
    // Small delay to ensure KaTeX auto-render is loaded
    setTimeout(() => renderMath(), 100);
  });

  return { render: renderMath };
})();
