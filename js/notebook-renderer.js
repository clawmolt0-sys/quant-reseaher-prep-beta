/* ============================================
   NOTEBOOK RENDERER — Client-side .ipynb viewer
   Renders Jupyter notebooks as interactive HTML
   with KaTeX math, syntax-highlighted code, and
   collapsible sections.
   ============================================ */

const NotebookRenderer = (() => {

  /**
   * Fetch and render a .ipynb file into a target element
   */
  async function render(notebookPath, targetEl) {
    targetEl.innerHTML = `
      <div class="nb-loading">
        <div class="empty-state__icon" style="font-size:2rem">&#9881;</div>
        <div style="color:var(--text-muted);font-size:var(--text-sm)">Loading notebook...</div>
      </div>
    `;

    try {
      const resp = await fetch(notebookPath);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const nb = await resp.json();
      const html = renderNotebook(nb);
      targetEl.innerHTML = html;

      // Render math with KaTeX
      if (typeof renderMathInElement === 'function') {
        renderMathInElement(targetEl, {
          delimiters: [
            { left: '$$', right: '$$', display: true },
            { left: '$', right: '$', display: false },
            { left: '\\[', right: '\\]', display: true },
            { left: '\\(', right: '\\)', display: false },
            { left: '\\begin{align}', right: '\\end{align}', display: true },
            { left: '\\begin{align*}', right: '\\end{align*}', display: true },
            { left: '\\begin{equation}', right: '\\end{equation}', display: true },
            { left: '\\begin{equation*}', right: '\\end{equation*}', display: true },
            { left: '\\begin{gather}', right: '\\end{gather}', display: true },
            { left: '\\begin{gather*}', right: '\\end{gather*}', display: true },
          ],
          throwOnError: false,
          trust: true,
          macros: {
            '\\R': '\\mathbb{R}',
            '\\E': '\\mathbb{E}',
            '\\P': '\\mathbb{P}',
            '\\Var': '\\text{Var}',
            '\\Cov': '\\text{Cov}',
            '\\Corr': '\\text{Corr}',
            '\\N': '\\mathcal{N}',
            '\\iid': '\\stackrel{\\text{iid}}{\\sim}',
          },
        });
      }
    } catch (err) {
      targetEl.innerHTML = `
        <div class="empty-state" style="min-height:200px">
          <div class="empty-state__icon">&#128466;</div>
          <div class="empty-state__title">Could not load notebook</div>
          <p style="color:var(--text-muted);font-size:var(--text-sm)">${err.message}</p>
        </div>
      `;
    }
  }

  /**
   * Convert notebook JSON to HTML string
   */
  function renderNotebook(nb) {
    const cells = nb.cells || [];
    let html = '<div class="nb">';
    let sectionOpen = false;

    for (let i = 0; i < cells.length; i++) {
      const cell = cells[i];
      const src = getSource(cell);

      if (cell.cell_type === 'markdown') {
        // Check if this is a section header (H1)
        const isH1 = /^#\s+[^#]/.test(src.trim());
        const isHR = /^\*{3,}$|^-{3,}$/.test(src.trim());

        if (isHR) continue; // skip horizontal rules

        html += `<div class="nb-cell nb-cell--md">${markdownToHtml(src)}</div>`;
      } else if (cell.cell_type === 'code') {
        const outputs = cell.outputs || [];
        const hasOutput = outputs.length > 0;

        html += `<div class="nb-cell nb-cell--code">`;
        html += `<div class="nb-code-container">`;
        html += `<div class="nb-code-label">Python</div>`;
        html += `<pre class="nb-code"><code>${escapeHtml(src)}</code></pre>`;
        html += `</div>`;

        if (hasOutput) {
          html += renderOutputs(outputs);
        }

        html += `</div>`;
      }
    }

    html += '</div>';
    return html;
  }

  /**
   * Get source text from a cell (handles string or array)
   */
  function getSource(cell) {
    const src = cell.source;
    if (Array.isArray(src)) return src.join('');
    return src || '';
  }

  /**
   * Convert markdown to HTML (lightweight parser)
   */
  function markdownToHtml(md) {
    // DRW content stripping — remove references to DRW
    md = md.replace(/DRW\s+New-Hire\s+Learning\s+Program/gi, 'Quant Finance Program');
    md = md.replace(/###\s*DRW.*$/gm, '');
    md = md.replace(/####\s*Summer\s+2023.*$/gm, '');
    md = md.replace(/\*\s*Contact:\s*Mark\s+Hendricks.*$/gm, '');
    md = md.replace(/\*\s*hendricks@.*$/gm, '');
    md = md.replace(/https:\/\/PollEv\.com\/.*$/gm, '');

    let html = md;

    // Process line by line for block elements
    const lines = html.split('\n');
    let result = [];
    let inList = false;
    let inTable = false;
    let inBlockquote = false;
    let blockquoteLines = [];
    let tableRows = [];

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i];

      // Blockquotes (> prefix)
      if (/^>\s?(.*)$/.test(line.trim())) {
        if (inList) { result.push('</ul>'); inList = false; }
        if (inTable) { result.push(renderTable(tableRows)); inTable = false; tableRows = []; }
        if (!inBlockquote) { inBlockquote = true; blockquoteLines = []; }
        blockquoteLines.push(RegExp.$1);
        continue;
      } else if (inBlockquote) {
        result.push(renderBlockquote(blockquoteLines));
        inBlockquote = false;
        blockquoteLines = [];
      }

      // Headers
      if (/^######\s+(.+)$/.test(line)) {
        if (inList) { result.push('</ul>'); inList = false; }
        result.push(`<h6 class="nb-h6">${RegExp.$1}</h6>`);
        continue;
      }
      if (/^#####\s+(.+)$/.test(line)) {
        if (inList) { result.push('</ul>'); inList = false; }
        result.push(`<h5 class="nb-h5">${RegExp.$1}</h5>`);
        continue;
      }
      if (/^####\s+(.+)$/.test(line)) {
        if (inList) { result.push('</ul>'); inList = false; }
        result.push(`<h4 class="nb-h4">${RegExp.$1}</h4>`);
        continue;
      }
      if (/^###\s+(.+)$/.test(line)) {
        if (inList) { result.push('</ul>'); inList = false; }
        result.push(`<h3 class="nb-h3">${RegExp.$1}</h3>`);
        continue;
      }
      if (/^##\s+(.+)$/.test(line)) {
        if (inList) { result.push('</ul>'); inList = false; }
        result.push(`<h2 class="nb-h2">${RegExp.$1}</h2>`);
        continue;
      }
      if (/^#\s+(.+)$/.test(line)) {
        if (inList) { result.push('</ul>'); inList = false; }
        result.push(`<h1 class="nb-h1">${RegExp.$1}</h1>`);
        continue;
      }

      // Table rows
      if (/^\|(.+)\|$/.test(line.trim())) {
        if (inList) { result.push('</ul>'); inList = false; }
        // Check for separator row
        if (/^\|[-:\s|]+\|$/.test(line.trim())) {
          continue; // skip separator
        }
        if (!inTable) {
          inTable = true;
          tableRows = [];
        }
        const cells = line.trim().slice(1, -1).split('|').map(c => c.trim());
        tableRows.push(cells);
        continue;
      } else if (inTable) {
        // End table
        result.push(renderTable(tableRows));
        inTable = false;
        tableRows = [];
      }

      // List items
      if (/^[\*\-]\s+(.+)$/.test(line.trim())) {
        if (!inList) { result.push('<ul class="nb-list">'); inList = true; }
        result.push(`<li>${inlineFormat(RegExp.$1)}</li>`);
        continue;
      } else if (inList && line.trim() === '') {
        result.push('</ul>');
        inList = false;
        continue;
      }

      // Numbered list
      if (/^\d+\.\s+(.+)$/.test(line.trim())) {
        if (!inList) { result.push('<ol class="nb-list nb-list--ordered">'); inList = true; }
        result.push(`<li>${inlineFormat(RegExp.$1)}</li>`);
        continue;
      }

      // Fenced code blocks (``` ... ```)
      if (/^```/.test(line.trim())) {
        if (inList) { result.push('</ul>'); inList = false; }
        // Gather lines until closing ```
        const lang = line.trim().replace(/^```/, '').trim() || '';
        let codeLines = [];
        i++;
        while (i < lines.length && !/^```\s*$/.test(lines[i].trim())) {
          codeLines.push(lines[i]);
          i++;
        }
        result.push(`<div class="nb-code-container"><pre class="nb-code"><code>${escapeHtml(codeLines.join('\n'))}</code></pre></div>`);
        continue;
      }

      // Image (skip — we don't have the assets)
      if (/^<img\s/.test(line.trim())) {
        continue;
      }

      // Horizontal rule
      if (/^(-{3,}|\*{3,}|_{3,})\s*$/.test(line.trim())) {
        if (inList) { result.push('</ul>'); inList = false; }
        result.push('<hr class="nb-hr">');
        continue;
      }

      // Lines that are only newcommand definitions — render them (KaTeX will process) but hide
      if (/^\$\\newcommand/.test(line.trim()) && /\}\$\s*$/.test(line.trim())) {
        result.push(`<span style="display:none">${line.trim()}</span>`);
        continue;
      }

      // Empty line
      if (line.trim() === '') {
        if (inList) { result.push('</ul>'); inList = false; }
        continue;
      }

      // Paragraph
      if (inList) { result.push('</ul>'); inList = false; }
      result.push(`<p class="nb-p">${inlineFormat(line)}</p>`);
    }

    if (inList) result.push('</ul>');
    if (inTable) result.push(renderTable(tableRows));
    if (inBlockquote) result.push(renderBlockquote(blockquoteLines));

    return result.join('\n');
  }

  /**
   * Render a blockquote with optional callout type detection
   */
  function renderBlockquote(lines) {
    const text = lines.join('\n');
    let extraClass = '';

    // Detect callout type from first line
    if (/💡|Interview\s+Tip|Key\s+Insight/i.test(text)) {
      extraClass = ' nb-blockquote--tip';
    } else if (/📝|Example|Worked\s+Problem/i.test(text)) {
      extraClass = ' nb-blockquote--example';
    } else if (/⚠|Warning|Caution|Common\s+Mistake/i.test(text)) {
      extraClass = ' nb-blockquote--warning';
    } else if (/📖|Definition|Theorem|Lemma/i.test(text)) {
      extraClass = ' nb-blockquote--definition';
    }

    const htmlContent = lines
      .map(l => l.trim() === '' ? '</p><p>' : inlineFormat(l))
      .join(' ');

    return `<blockquote class="nb-blockquote${extraClass}"><p>${htmlContent}</p></blockquote>`;
  }

  /**
   * Inline formatting: bold, italic, code, links
   */
  function inlineFormat(text) {
    // Code spans (do first to avoid conflicts)
    text = text.replace(/`([^`]+)`/g, '<code class="nb-inline-code">$1</code>');
    // Bold + italic
    text = text.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
    // Bold
    text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    // Italic
    text = text.replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, '<em>$1</em>');
    // Links
    text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener" class="nb-link">$1</a>');
    // Standalone URLs
    text = text.replace(/(^|\s)(https?:\/\/[^\s<]+)/g, '$1<a href="$2" target="_blank" rel="noopener" class="nb-link">$2</a>');

    return text;
  }

  /**
   * Render a table from rows
   */
  function renderTable(rows) {
    if (rows.length === 0) return '';
    let html = '<div class="nb-table-wrap"><table class="nb-table">';
    // First row is header
    html += '<thead><tr>';
    rows[0].forEach(cell => { html += `<th>${inlineFormat(cell)}</th>`; });
    html += '</tr></thead>';
    // Remaining rows
    if (rows.length > 1) {
      html += '<tbody>';
      for (let i = 1; i < rows.length; i++) {
        html += '<tr>';
        rows[i].forEach(cell => { html += `<td>${inlineFormat(cell)}</td>`; });
        html += '</tr>';
      }
      html += '</tbody>';
    }
    html += '</table></div>';
    return html;
  }

  /**
   * Render cell outputs
   */
  function renderOutputs(outputs) {
    let html = '';
    for (const output of outputs) {
      if (output.output_type === 'stream') {
        const text = (output.text || []).join('');
        if (text.trim()) {
          html += `<pre class="nb-output nb-output--text">${escapeHtml(text)}</pre>`;
        }
      } else if (output.output_type === 'execute_result' || output.output_type === 'display_data') {
        const data = output.data || {};
        // Prefer HTML output, then text
        if (data['image/png']) {
          html += `<div class="nb-output nb-output--image"><img src="data:image/png;base64,${data['image/png']}" alt="Output" /></div>`;
        } else if (data['text/html']) {
          const htmlContent = Array.isArray(data['text/html']) ? data['text/html'].join('') : data['text/html'];
          html += `<div class="nb-output nb-output--html">${htmlContent}</div>`;
        } else if (data['text/plain']) {
          const text = Array.isArray(data['text/plain']) ? data['text/plain'].join('') : data['text/plain'];
          html += `<pre class="nb-output nb-output--text">${escapeHtml(text)}</pre>`;
        }
      } else if (output.output_type === 'error') {
        // Skip errors in rendered view
      }
    }
    return html;
  }

  function escapeHtml(str) {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  return { render };
})();
