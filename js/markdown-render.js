/* ============================================
   MARKDOWN RENDER — Shared lightweight markdown-to-HTML
   Extracted from notebook-renderer.js for reuse
   across problems, solutions, and notebook content.
   ============================================ */

const MarkdownRender = (() => {

  function escapeHtml(str) {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  /**
   * Inline formatting: bold, italic, code, links
   */
  function inlineFormat(text) {
    // Code spans (do first to avoid conflicts)
    text = text.replace(/`([^`]+)`/g, '<code class="md-inline-code">$1</code>');
    // Bold + italic
    text = text.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
    // Bold
    text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    // Italic
    text = text.replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, '<em>$1</em>');
    // Links
    text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');

    return text;
  }

  /**
   * Render a blockquote with optional callout type detection
   */
  function renderBlockquote(lines) {
    const text = lines.join('\n');
    let extraClass = '';

    if (/💡|Intuition|Key\s+Insight|Tip/i.test(text)) {
      extraClass = ' md-blockquote--tip';
    } else if (/📝|Example|Worked\s+Problem/i.test(text)) {
      extraClass = ' md-blockquote--example';
    } else if (/⚠|Warning|Caution|Common\s+Mistake/i.test(text)) {
      extraClass = ' md-blockquote--warning';
    } else if (/📖|Definition|Theorem|Lemma/i.test(text)) {
      extraClass = ' md-blockquote--definition';
    }

    const htmlContent = lines
      .map(l => l.trim() === '' ? '</p><p>' : inlineFormat(l))
      .join(' ');

    return `<blockquote class="md-blockquote${extraClass}"><p>${htmlContent}</p></blockquote>`;
  }

  /**
   * Render a table from rows
   */
  function renderTable(rows) {
    if (rows.length === 0) return '';
    let html = '<div class="md-table-wrap"><table class="md-table">';
    html += '<thead><tr>';
    rows[0].forEach(cell => { html += `<th>${inlineFormat(cell)}</th>`; });
    html += '</tr></thead>';
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
   * Protect math blocks from paragraph wrapping.
   * Extracts display math ($$...$$) and LaTeX environments
   * (\begin{...}...\end{...}) spanning multiple lines,
   * replacing them with placeholders. After markdown processing,
   * the placeholders are restored.
   */
  function protectMathBlocks(md) {
    const placeholders = [];
    let counter = 0;

    // Protect multi-line display math: $$...$$ spanning multiple lines
    md = md.replace(/\$\$([\s\S]*?)\$\$/g, (match) => {
      const key = `\x00MATH${counter++}\x00`;
      placeholders.push({ key, value: match });
      return key;
    });

    // Protect LaTeX environments: \begin{...}...\end{...}
    md = md.replace(/\\begin\{([^}]+)\}([\s\S]*?)\\end\{\1\}/g, (match) => {
      const key = `\x00MATH${counter++}\x00`;
      placeholders.push({ key, value: match });
      return key;
    });

    return { md, placeholders };
  }

  function restoreMathBlocks(html, placeholders) {
    for (const { key, value } of placeholders) {
      // The placeholder might be wrapped in a <p> tag — unwrap it
      const escaped = key.replace(/\x00/g, '\\x00');
      // Try wrapped in paragraph first
      const pWrapped = `<p class="md-p">${key}</p>`;
      if (html.includes(pWrapped)) {
        html = html.replace(pWrapped, value);
      } else {
        html = html.replace(key, value);
      }
    }
    return html;
  }

  /**
   * Convert markdown string to HTML
   */
  function render(md) {
    if (!md) return '';

    // Protect math blocks before processing
    const { md: safeMd, placeholders } = protectMathBlocks(md);

    const lines = safeMd.split('\n');
    let result = [];
    let inList = false;
    let listType = 'ul'; // 'ul' or 'ol'
    let inTable = false;
    let inBlockquote = false;
    let blockquoteLines = [];
    let tableRows = [];

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i];

      // Blockquotes (> prefix)
      if (/^>\s?(.*)$/.test(line.trim())) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
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
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        result.push(`<h6 class="md-h6">${inlineFormat(RegExp.$1)}</h6>`);
        continue;
      }
      if (/^#####\s+(.+)$/.test(line)) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        result.push(`<h5 class="md-h5">${inlineFormat(RegExp.$1)}</h5>`);
        continue;
      }
      if (/^####\s+(.+)$/.test(line)) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        result.push(`<h4 class="md-h4">${inlineFormat(RegExp.$1)}</h4>`);
        continue;
      }
      if (/^###\s+(.+)$/.test(line)) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        result.push(`<h3 class="md-h3">${inlineFormat(RegExp.$1)}</h3>`);
        continue;
      }
      if (/^##\s+(.+)$/.test(line)) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        result.push(`<h2 class="md-h2">${inlineFormat(RegExp.$1)}</h2>`);
        continue;
      }
      if (/^#\s+(.+)$/.test(line)) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        result.push(`<h1 class="md-h1">${inlineFormat(RegExp.$1)}</h1>`);
        continue;
      }

      // Table rows
      if (/^\|(.+)\|$/.test(line.trim())) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        if (/^\|[-:\s|]+\|$/.test(line.trim())) continue; // skip separator
        if (!inTable) { inTable = true; tableRows = []; }
        const cells = line.trim().slice(1, -1).split('|').map(c => c.trim());
        tableRows.push(cells);
        continue;
      } else if (inTable) {
        result.push(renderTable(tableRows));
        inTable = false;
        tableRows = [];
      }

      // Unordered list items
      if (/^[\*\-]\s+(.+)$/.test(line.trim())) {
        if (inList && listType !== 'ul') { result.push('</ol>'); inList = false; }
        if (!inList) { result.push('<ul class="md-list">'); inList = true; listType = 'ul'; }
        result.push(`<li>${inlineFormat(RegExp.$1)}</li>`);
        continue;
      }

      // Ordered list items
      if (/^\d+\.\s+(.+)$/.test(line.trim())) {
        if (inList && listType !== 'ol') { result.push('</ul>'); inList = false; }
        if (!inList) { result.push('<ol class="md-list md-list--ordered">'); inList = true; listType = 'ol'; }
        result.push(`<li>${inlineFormat(RegExp.$1)}</li>`);
        continue;
      }

      // End list on non-list line
      if (inList && line.trim() === '') {
        result.push(listType === 'ol' ? '</ol>' : '</ul>');
        inList = false;
        continue;
      }

      // Fenced code blocks
      if (/^```/.test(line.trim())) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        const lang = line.trim().replace(/^```/, '').trim() || '';
        let codeLines = [];
        i++;
        while (i < lines.length && !/^```\s*$/.test(lines[i].trim())) {
          codeLines.push(lines[i]);
          i++;
        }
        const langLabel = lang ? `<div class="md-code-label">${lang}</div>` : '';
        result.push(`<div class="md-code-container">${langLabel}<pre class="md-code"><code>${escapeHtml(codeLines.join('\n'))}</code></pre></div>`);
        continue;
      }

      // Horizontal rule
      if (/^(-{3,}|\*{3,}|_{3,})\s*$/.test(line.trim())) {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        result.push('<hr class="md-hr">');
        continue;
      }

      // KaTeX newcommand definitions — render hidden
      if (/^\$\\newcommand/.test(line.trim()) && /\}\$\s*$/.test(line.trim())) {
        result.push(`<span style="display:none">${line.trim()}</span>`);
        continue;
      }

      // Empty line
      if (line.trim() === '') {
        if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
        continue;
      }

      // Paragraph
      if (inList) { result.push(listType === 'ol' ? '</ol>' : '</ul>'); inList = false; }
      result.push(`<p class="md-p">${inlineFormat(line)}</p>`);
    }

    if (inList) result.push(listType === 'ol' ? '</ol>' : '</ul>');
    if (inTable) result.push(renderTable(tableRows));
    if (inBlockquote) result.push(renderBlockquote(blockquoteLines));

    let html = result.join('\n');

    // Restore math blocks
    html = restoreMathBlocks(html, placeholders);

    return html;
  }

  return { render, inlineFormat, escapeHtml };
})();
