const AppState = {
  includeSet: new Set(),
  excludeSet: new Set(),
  allTags: new Set(),
  logs: [],
  isLoading: false,
  refreshInterval: null,
  toggleAllState: 'select',
  loadingTimer: null,
  tagDetectScope: [],
  tagDetectScopeOriginal: [],
  tagToFilesLower: {}
};

const Config = {
  REFRESH_INTERVAL: 5000,
  NOTIFICATION_DURATION: 3000,
  DEBOUNCE_DELAY: 300,
  MAX_LOGS_DISPLAY: 100 
};


/**
 * Debounce function for performance
 */
const debounce = (func, wait) => {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
};

/**
 * Smooth scroll to element
 */
const smoothScrollTo = (element) => {
  element.scrollIntoView({
    behavior: 'smooth',
    block: 'start',
    inline: 'nearest'
  });
};

/**
 * Format numbers with commas
 */
const formatNumber = (num) => {
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
};

/**
 * Animate number counter
 */
const animateCounter = (element, start, end, duration) => {
  const range = end - start;
  const increment = end > start ? 1 : -1;
  const stepTime = Math.abs(Math.floor(duration / range));
  let current = start;
  
  const timer = setInterval(() => {
    current += increment;
    element.textContent = formatNumber(current);
    
    if (current === end) {
      clearInterval(timer);
      element.classList.add('pulse-once');
      setTimeout(() => element.classList.remove('pulse-once'), 600);
    }
  }, stepTime);
};


class NotificationManager {
  constructor() {
    this.queue = [];
    this.isShowing = false;
  }
  
  show(message, type = 'success') {
    this.queue.push({ message, type });
    this.processQueue();
  }
  
  processQueue() {
    if (this.isShowing || this.queue.length === 0) return;
    
    this.isShowing = true;
    const { message, type } = this.queue.shift();
    
    const notification = document.getElementById('notification');
    const messageEl = notification.querySelector('.notification-message');
    const iconEl = notification.querySelector('.notification-icon');
    
    messageEl.textContent = message;
    
    const icons = {
      success: '<path d="M9 11l4 4 8-8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
      error: '<path d="M6 6l12 12M6 18L18 6" stroke-width="2" stroke-linecap="round"/>',
      info: '<path d="M12 2v10m0 4v2m0 0a1 1 0 100-2 1 1 0 000 2z" stroke-width="2"/>',
      warning: '<path d="M12 8v4m0 4h.01" stroke-width="2" stroke-linecap="round"/>'
    };
    
    iconEl.innerHTML = icons[type] || icons.success;

    // Dynamic coloring by type
    const colorMap = {
      success: 'var(--accent-success)',
      error: 'var(--accent-danger)',
      warning: 'var(--accent-warning)',
      info: 'var(--accent-primary)'
    };
    iconEl.style.color = colorMap[type] || colorMap.success;
    notification.dataset.type = type;
    
    notification.style.borderColor = type === 'error' ? 'var(--accent-danger)' : 
                                     type === 'warning' ? 'var(--accent-warning)' : 
                                     'var(--border-interactive)';
    
    notification.classList.add('show');
    
    setTimeout(() => {
      notification.classList.remove('show');
      this.isShowing = false;
      
      setTimeout(() => this.processQueue(), 300);
    }, Config.NOTIFICATION_DURATION);
  }
}

const notifications = new NotificationManager();


async function copyText(id) {
  const element = document.getElementById(id);
  if (!element) return;
  
  const value = element.value || element.textContent || '';
  
  try {
    await navigator.clipboard.writeText(String(value));
    
    element.classList.add('copied');
    setTimeout(() => element.classList.remove('copied'), 1000);
    
    notifications.show('Copied to clipboard', 'success');
  } catch (err) {
    try {
      const range = document.createRange();
      range.selectNode(element);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      document.execCommand('copy');
      selection.removeAllRanges();
      
      notifications.show('Copied to clipboard', 'success');
    } catch (fallbackErr) {
      notifications.show('Failed to copy', 'error');
    }
  }
}


class NavigationController {
  constructor() {
    this.sections = [...document.querySelectorAll('section')];
    this.navItems = [...document.querySelectorAll('.nav-item')];
    this.activeSection = null;
    
    this.init();
  }
  
  init() {
    this.navItems.forEach(item => {
      item.addEventListener('click', (e) => {
        e.preventDefault();
        const targetId = item.getAttribute('href').slice(1);
        const targetSection = document.getElementById(targetId);
        
        if (targetSection) {
          smoothScrollTo(targetSection);
          this.setActive(item);
        }
      });
    });
    
    window.addEventListener('scroll', debounce(() => this.updateActiveOnScroll(), 50), { passive: true });
    
    this.updateActiveOnScroll();
  }
  
  updateActiveOnScroll() {
    const scrollPosition = window.scrollY + 120;
    let currentSection = this.sections[0];
    
    for (const section of this.sections) {
      if (section.offsetTop <= scrollPosition) {
        currentSection = section;
      }
    }
    
    const activeItem = this.navItems.find(item => 
      item.getAttribute('href') === `#${currentSection.id}`
    );
    
    if (activeItem) {
      this.setActive(activeItem);
    }
  }
  
  setActive(item) {
    this.navItems.forEach(navItem => {
      navItem.classList.remove('active');
      navItem.style.transform = '';
      navItem.removeAttribute('aria-current');
    });
    
    item.classList.add('active');
    item.setAttribute('aria-current', 'page');
    
    item.style.transform = 'scale(1.05)';
    setTimeout(() => {
      item.style.transform = '';
    }, 200);
  }
}


class DataManager {
  async updateStats(silent = false) {
    try {
      AppState.isLoading = true;
      if (!silent) this.showLoadingState();
      
      const response = await fetch('/logs');
      const data = await response.json();
      
      const total = data.total || 0;
      const requestCountEl = document.getElementById('requestCount');
      
      if (requestCountEl) {
        const currentValue = parseInt(requestCountEl.textContent.replace(/,/g, '') || '0');
        if (currentValue !== total) {
          animateCounter(requestCountEl, currentValue, total, 500);
        }
      }
      
      this.renderLogs(data.logs || [], !silent);
      
    } catch (error) {
      console.error('Failed to update stats:', error);
      notifications.show('Failed to load data', 'error');
    } finally {
      AppState.isLoading = false;
      if (!silent) this.hideLoadingState();
    }
  }
  
  renderLogs(logs, animate = false) {
    AppState.logs = logs;
    const filter = (document.getElementById('logFilter')?.value || '').toLowerCase().trim();
    const logsContainer = document.getElementById('logs');
    
    if (!logsContainer) return;
    
    const filteredLogs = logs.filter(log => 
      !filter || log.toLowerCase().includes(filter)
    ).slice(0, Config.MAX_LOGS_DISPLAY);
    
    if (filteredLogs.length === 0) {
      this.renderEmptyState(logsContainer);
      return;
    }
    
    const logElements = filteredLogs.map((name, index) => {
      const logItem = document.createElement('div');
      logItem.className = 'log-item';
      logItem.dataset.name = name;
      if (animate) {
        logItem.style.animationDelay = `${index * 20}ms`;
      }
      const left = AppState.selectingLogs ? `
        <span class="log-filename">${this.escapeHtml(name)}</span>
      ` : `
        <div class="log-left">
          <span class="log-filename">${this.escapeHtml(name)}</span>
          <button class="mini-btn mini-txt-btn loud" title="View parsed TXT" aria-label="View parsed TXT for ${this.escapeHtml(name)}">TXT</button>
          <button class="icon-btn mini-rename-btn" title="Rename log" aria-label="Rename ${this.escapeHtml(name)}">✎</button>
        </div>
      `;
      const right = `<span class="log-time">${this.getRelativeTime()}</span>`;
      logItem.innerHTML = `${left}${right}`;
      // Selection support
      if (AppState.selectingLogs) {
        logItem.classList.add('selectable');
        if (AppState.selectedLogs && AppState.selectedLogs.has(name)) {
          logItem.classList.add('active');
          logItem.setAttribute('aria-selected', 'true');
        } else {
          logItem.removeAttribute('aria-selected');
        }
        logItem.addEventListener('click', (e) => this.toggleLogSelection(e, name, logItem));
      } else {
        logItem.addEventListener('click', (ev) => {
          // If inline rename is active on this row, do not open
          if (logItem.querySelector('.inline-rename')) {
            try { ev.preventDefault(); ev.stopPropagation(); } catch (_) {}
            return;
          }
          this.openLog(name);
        });
        const txtBtn = logItem.querySelector('.mini-txt-btn');
        if (txtBtn) {
          const stopAll = (e) => { try { e.preventDefault(); e.stopPropagation(); } catch (_) {} };
          txtBtn.addEventListener('pointerdown', stopAll, { passive: false });
          txtBtn.addEventListener('mousedown', stopAll, { passive: false });
          txtBtn.addEventListener('click', (e) => {
            stopAll(e);
            this.openParsedList(name);
          }, { passive: false });
        }
        const rnBtn = logItem.querySelector('.mini-rename-btn');
        if (rnBtn) {
          const stopAll = (e) => { try { e.preventDefault(); e.stopPropagation(); } catch (_) {} };
          rnBtn.addEventListener('pointerdown', stopAll, { passive: false });
          rnBtn.addEventListener('mousedown', stopAll, { passive: false });
          rnBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            const left = logItem.querySelector('.log-left');
            if (!left) return;
            const nameSpan = left.querySelector('.log-filename');
            const txtButton = left.querySelector('.mini-txt-btn');
            const pencil = rnBtn;

            // Prevent double init
            if (left.querySelector('.inline-rename')) return;

            // Hide existing elements
            if (nameSpan) nameSpan.style.display = 'none';
            if (txtButton) txtButton.style.display = 'none';
            if (pencil) pencil.style.display = 'none';

            // Inline editor
            const wrap = document.createElement('div');
            wrap.className = 'inline-rename';
            wrap.addEventListener('click', stopAll, { passive: false });
            const input = document.createElement('input');
            input.className = 'copy-input rename-input';
            input.value = name;
            input.style.flex = '1';
            const cancelBtn = document.createElement('button');
            cancelBtn.className = 'button button-secondary';
            cancelBtn.textContent = 'Cancel';
            const saveBtn = document.createElement('button');
            saveBtn.className = 'button';
            saveBtn.textContent = 'Save';
            wrap.appendChild(input);
            wrap.appendChild(cancelBtn);
            wrap.appendChild(saveBtn);
            left.appendChild(wrap);

            setTimeout(() => { try { input.focus(); input.select(); } catch (_) {} }, 0);

            const cleanup = () => {
              try { left.removeChild(wrap); } catch (_) {}
              if (nameSpan) nameSpan.style.display = '';
              if (txtButton) txtButton.style.display = '';
              if (pencil) pencil.style.display = '';
            };

            cancelBtn.addEventListener('click', (ev) => { stopAll(ev); cleanup(); });
            input.addEventListener('keydown', (ev) => {
              if (ev.key === 'Enter') { ev.preventDefault(); saveBtn.click(); }
              if (ev.key === 'Escape') { ev.preventDefault(); cancelBtn.click(); }
            }, { passive: false });
            saveBtn.addEventListener('click', async (ev) => {
              stopAll(ev);
              const newName = (input.value || '').trim();
              if (!newName || newName === name) { cleanup(); return; }
              try {
                const res = await fetch(`/logs/${encodeURIComponent(name)}/rename`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ new_name: newName })
                });
                if (res.ok) {
                  notifications.show('Log renamed', 'success');
                  await dataManager.updateStats();
                } else {
                  const err = await res.json().catch(() => ({}));
                  notifications.show(err.error || 'Rename failed', 'error');
                }
              } catch (_) {
                notifications.show('Rename failed', 'error');
              } finally {
                cleanup();
              }
            });
          });
        }
      }
      
      return logItem;
    });
    
    logsContainer.innerHTML = '';
    logElements.forEach(el => {
      if (animate) {
        el.classList.add('fade-in-up');
      }
      logsContainer.appendChild(el);
    });
  }

  async openParsedList(name) {
    try {
      const res = await fetch(`/logs/${encodeURIComponent(name)}/parsed`);
      if (!res.ok) throw new Error('Failed to fetch parsed versions');
      const data = await res.json();
      const versions = Array.isArray(data.versions) ? data.versions : [];
      if (!versions.length) {
        notifications.show('No parsed TXT versions for this log yet', 'info');
        return;
      }

      const listItems = versions.map(v => {
        const date = this.formatDateTime(v.mtime);
        const sizeKb = Math.max(1, Math.round((v.size || 0) / 1024));
        const latest = (data.latest && v.file === data.latest) ? '<span class="badge-latest">Latest</span>' : '';
        const vlabel = (v.version && Number.isInteger(v.version)) ? `v${v.version}` : '';
        return `<li>
          <div class="version-left">
            <button class="version-item" data-id="${this.escapeHtml(v.file)}">${vlabel ? this.escapeHtml(vlabel) + ' · ' : ''}${this.escapeHtml(v.file)}</button>
            <button class="icon-btn version-rename" title="Rename parsed file" data-id="${this.escapeHtml(v.file)}">✎</button>
          </div>
          <span class="meta">${latest} ${date} • ${sizeKb} KB</span>
        </li>`;
      }).join('');

      const html = `
        <div class="version-picker">
          <div class="version-header">Parsed TXT Versions</div>
          <ul class="version-list">${listItems}</ul>
        </div>
      `;

      const modal = new Modal();
      modal.showHtml(`${name} — TXT`, html);
      modal.setBackHandler(null);

      const bodyEl = document.getElementById('modalBody');
      if (bodyEl) {
        bodyEl.querySelectorAll('.version-item').forEach(btn => {
          btn.addEventListener('click', async (e) => {
            const id = btn.getAttribute('data-id');
            if (!id) return;
            try {
              const r = await fetch(`/logs/${encodeURIComponent(name)}/parsed/${encodeURIComponent(id)}`);
              if (!r.ok) throw new Error('Failed to load parsed content');
              const text = await r.text();
              modal.show(`${name} — ${id}`, text);
              modal.setBackHandler(() => {
                this.openParsedList(name);
              });
            } catch (err) {
              notifications.show('Failed to load parsed content', 'error');
            }
          });
        });
        bodyEl.querySelectorAll('.version-rename').forEach(btn => {
          btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const id = btn.getAttribute('data-id');
            if (!id) return;
            // Replace the button row with inline rename controls
            const parentLi = btn.closest('li');
            if (!parentLi) return;
            const left = parentLi.querySelector('.version-left');
            if (!left) return;
            if (left.querySelector('.inline-rename')) return;
            const nameBtn = left.querySelector('.version-item');
            const pencil = btn;
            if (nameBtn) nameBtn.style.display = 'none';
            if (pencil) pencil.style.display = 'none';

            const wrap = document.createElement('div');
            wrap.className = 'inline-rename';
            const input = document.createElement('input');
            input.className = 'copy-input rename-input';
            input.value = id;
            input.style.flex = '1';
            const cancelBtn = document.createElement('button');
            cancelBtn.className = 'button button-secondary';
            cancelBtn.textContent = 'Cancel';
            const saveBtn = document.createElement('button');
            saveBtn.className = 'button';
            saveBtn.textContent = 'Save';
            wrap.appendChild(input);
            wrap.appendChild(cancelBtn);
            wrap.appendChild(saveBtn);
            left.appendChild(wrap);
            setTimeout(() => { try { input.focus(); input.select(); } catch (_) {} }, 0);

            const cleanup = () => {
              try { left.removeChild(wrap); } catch (_) {}
              if (nameBtn) nameBtn.style.display = '';
              if (pencil) pencil.style.display = '';
            };
            cancelBtn.addEventListener('click', (ev) => { ev.stopPropagation(); cleanup(); });
            input.addEventListener('keydown', (ev) => {
              if (ev.key === 'Enter') { ev.preventDefault(); saveBtn.click(); }
              if (ev.key === 'Escape') { ev.preventDefault(); cancelBtn.click(); }
            }, { passive: false });
            saveBtn.addEventListener('click', async (ev) => {
              ev.stopPropagation();
              const newName = (input.value || '').trim();
              if (!newName || newName === id) { cleanup(); return; }
              try {
                const r = await fetch(`/logs/${encodeURIComponent(name)}/parsed/rename`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ old: id, new: newName })
                });
                if (!r.ok) {
                  const err = await r.json().catch(() => ({}));
                  notifications.show(err.error || 'Rename failed', 'error');
                  return;
                }
                notifications.show('Parsed file renamed', 'success');
                this.openParsedList(name);
              } catch (_) {
                notifications.show('Rename failed', 'error');
              } finally {
                cleanup();
              }
            });
          });
        });
      }
    } catch (err) {
      console.error(err);
      notifications.show('Failed to load parsed versions', 'error');
    }
  }

  formatDateTime(unixSeconds) {
    if (!unixSeconds) return '';
    try {
      const d = new Date(unixSeconds * 1000);
      const y = d.getFullYear();
      const m = String(d.getMonth() + 1).padStart(2, '0');
      const day = String(d.getDate()).padStart(2, '0');
      const hh = String(d.getHours()).padStart(2, '0');
      const mm = String(d.getMinutes()).padStart(2, '0');
      const ss = String(d.getSeconds()).padStart(2, '0');
      return `${y}-${m}-${day} ${hh}:${mm}:${ss}`;
    } catch (_) {
      return '';
    }
  }

  toggleLogSelection(e, name, el) {
    e.stopPropagation();
    const set = AppState.selectedLogs;
    if (set.has(name)) {
      set.delete(name);
      el.classList.remove('active');
    } else {
      set.add(name);
      el.classList.add('active');
    }
    this.updateSelectionToolbar();
  }

  updateSelectionToolbar() {
    const toolbar = document.getElementById('selectionToolbar');
    if (!toolbar) return;
    const count = AppState.selectedLogs.size;
    toolbar.style.display = AppState.selectingLogs ? 'flex' : 'none';
    const toggleBtn = document.getElementById('toggleSelectAllBtn');
    if (toggleBtn) {
      const total = AppState.logs.length;
      toggleBtn.textContent = count === total ? 'Deselect All' : 'Select All';
    }
  }
  
  renderEmptyState(container) {
    container.innerHTML = `
      <div class="empty-state">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/>
          <path d="M12 6v6l4 2"/>
        </svg>
        <p>Waiting for requests...</p>
      </div>
    `;
  }
  
  async openLog(name) {
    try {
      const response = await fetch(`/logs/${encodeURIComponent(name)}`);
      const content = await response.text();
      
      const modal = new Modal();
      modal.show(name, content);
      
    } catch (error) {
      console.error('Failed to load log:', error);
      notifications.show('Failed to load log', 'error');
    }
  }
  
  async updateEndpoints(silent = false) {
    let cloudflareUrl = '';
    let localUrl = 'http://localhost:5000/openrouter-cc';

    // Fetch Cloudflare tunnel URL
    try {
      const response = await fetch('/tunnel');
      const data = await response.json();
      cloudflareUrl = data.url ? `${data.url}/openrouter-cc` : '';
    } catch (error) {
      console.error('Failed to fetch tunnel:', error);
    }

    // Fetch local server port from /health to avoid using Cloudflare hostname/port
    try {
      const healthRes = await fetch('/health');
      if (healthRes.ok) {
        const health = await healthRes.json();
        const port = health?.config?.port || 5000;
        localUrl = `http://localhost:${port}/openrouter-cc`;
      }
    } catch (error) {
      // Fallback remains http://localhost:5000/openrouter-cc
    }
    
    const cfInput = document.getElementById('endpointCloudflare');
    const localInput = document.getElementById('endpointLocal');
    
    if (cfInput) {
      if (silent) {
        cfInput.value = cloudflareUrl || 'Not available';
      } else {
        this.updateInputWithAnimation(cfInput, cloudflareUrl || 'Not available');
      }
    }
    
    if (localInput) {
      if (silent) {
        localInput.value = localUrl;
      } else {
        this.updateInputWithAnimation(localInput, localUrl);
      }
    }
    
    const cfButton = document.getElementById('openCloudflareBtn');
    if (cfButton) {
      cfButton.style.pointerEvents = cloudflareUrl ? 'auto' : 'none';
      cfButton.style.opacity = cloudflareUrl ? '1' : '0.5';
      cfButton.href = cloudflareUrl || '#';
    }
    
    const localButton = document.getElementById('openLocalBtn');
    if (localButton) {
      localButton.href = localUrl.replace('/openrouter-cc', '/');
    }
  }
  
  updateInputWithAnimation(input, value) {
    if (input.value !== value) {
      input.classList.add('updating');
      setTimeout(() => {
        input.value = value;
        input.classList.remove('updating');
      }, 150);
    }
  }
  
  showLoadingState() {
    if (AppState.loadingTimer) return;
    AppState.loadingTimer = setTimeout(() => {
      document.querySelectorAll('.metric-card, .parameter-card').forEach(card => {
        card.classList.add('loading');
      });
    }, 200);
  }
  
  hideLoadingState() {
    if (AppState.loadingTimer) {
      clearTimeout(AppState.loadingTimer);
      AppState.loadingTimer = null;
    }
    document.querySelectorAll('.metric-card, .parameter-card').forEach(card => {
      card.classList.remove('loading');
    });
  }
  
  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
  
  getRelativeTime() {
    const now = new Date();
    const hours = now.getHours().toString().padStart(2, '0');
    const minutes = now.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }
}


class Modal {
  show(title, content) {
    const modalEl = document.getElementById('logModal');
    const titleEl = document.getElementById('modalTitle');
    const bodyEl = document.getElementById('modalBody');
    
    if (!modalEl || !titleEl || !bodyEl) return;
    
    titleEl.textContent = title;
    bodyEl.textContent = content;
    
    if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
      try {
        const parsed = JSON.parse(content);
        bodyEl.innerHTML = this.syntaxHighlight(JSON.stringify(parsed, null, 2));
      } catch (e) {
      }
    }
    
    modalEl.style.display = 'flex';
    
    // Focus management and keyboard support
    try {
      modalEl._prevFocus = document.activeElement || null;
      const panel = modalEl.querySelector('.modal-panel');
      const focusable = panel ? panel.querySelectorAll('a[href], button, textarea, input, select, [tabindex]:not([tabindex="-1"])') : [];
      const focusables = Array.from(focusable).filter(el => !el.hasAttribute('disabled'));
      if (focusables.length > 0) {
        focusables[0].focus();
      } else if (panel) {
        panel.setAttribute('tabindex', '-1');
        panel.focus();
      }
      modalEl._keydownHandler = (e) => {
        if (e.key === 'Escape') {
          e.preventDefault();
          this.hide();
          return;
        }
        if (e.key === 'Tab') {
          if (!focusables.length) {
            e.preventDefault();
            return;
          }
          const first = focusables[0];
          const last = focusables[focusables.length - 1];
          if (e.shiftKey) {
            if (document.activeElement === first) {
              e.preventDefault();
              last.focus();
            }
          } else {
            if (document.activeElement === last) {
              e.preventDefault();
              first.focus();
            }
          }
        }
      };
      document.addEventListener('keydown', modalEl._keydownHandler);
    } catch (_) {}

    requestAnimationFrame(() => {
      modalEl.classList.add('show');
    });
  }
  setBackHandler(handler) {
    const backBtn = document.getElementById('modalBackBtn');
    if (backBtn) {
      if (typeof handler === 'function') {
        backBtn.style.display = '';
        backBtn.onclick = (e) => { e.preventDefault(); handler(); };
      } else {
        backBtn.style.display = 'none';
        backBtn.onclick = null;
      }
    }
  }
  showHtml(title, html) {
    const modalEl = document.getElementById('logModal');
    const titleEl = document.getElementById('modalTitle');
    const bodyEl = document.getElementById('modalBody');
    if (!modalEl || !titleEl || !bodyEl) return;
    titleEl.textContent = title;
    bodyEl.innerHTML = html;
    modalEl.style.display = 'flex';
    try {
      modalEl._prevFocus = document.activeElement || null;
    } catch (_) {}
    requestAnimationFrame(() => {
      modalEl.classList.add('show');
    });
  }
  showInlineEditor(title, initial, onSave) {
    const modalEl = document.getElementById('logModal');
    const titleEl = document.getElementById('modalTitle');
    const bodyEl = document.getElementById('modalBody');
    if (!modalEl || !titleEl || !bodyEl) return;
    titleEl.textContent = title;
    bodyEl.innerHTML = `
      <div style="display:flex; gap:.5rem; align-items:center;">
        <input id="inlineEditInput" class="copy-input" style="flex:1" value="${this.escapeHtml ? this.escapeHtml(initial) : initial}" />
        <button class="button" id="inlineEditSave">Save</button>
        <button class="button button-secondary" id="inlineEditCancel">Cancel</button>
      </div>
    `;
    modalEl.style.display = 'flex';
    requestAnimationFrame(() => modalEl.classList.add('show'));
    const saveBtn = document.getElementById('inlineEditSave');
    const cancelBtn = document.getElementById('inlineEditCancel');
    const input = document.getElementById('inlineEditInput');
    if (input) setTimeout(() => input.focus(), 50);
    const cleanup = () => this.hide();
    if (cancelBtn) cancelBtn.addEventListener('click', cleanup);
    if (saveBtn) saveBtn.addEventListener('click', async () => {
      const val = input ? (input.value || '').trim() : '';
      if (!val) return;
      await onSave(val);
      cleanup();
    });
  }
  
  hide() {
    const modalEl = document.getElementById('logModal');
    if (!modalEl) return;
    
    try {
      if (modalEl._keydownHandler) {
        document.removeEventListener('keydown', modalEl._keydownHandler);
        modalEl._keydownHandler = null;
      }
    } catch (_) {}
    
    modalEl.classList.remove('show');
    
    setTimeout(() => {
      modalEl.style.display = 'none';
      try {
        const prev = modalEl._prevFocus;
        if (prev && typeof prev.focus === 'function') {
          prev.focus();
        }
        modalEl._prevFocus = null;
      } catch (_) {}
    }, 300);
  }
  
  syntaxHighlight(json) {
    json = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return json.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, (match) => {
      let cls = 'number';
      if (/^"/.test(match)) {
        if (/:$/.test(match)) {
          cls = 'key';
        } else {
          cls = 'string';
        }
      } else if (/true|false/.test(match)) {
        cls = 'boolean';
      } else if (/null/.test(match)) {
        cls = 'null';
      }
      return `<span class="json-${cls}">${match}</span>`;
    });
  }
}


class ParserController {
  constructor() {
    this.init();
    this._tagDetectSelection = new Set();
  }
  
  init() {
    this.loadSettings();
    this.setupEventListeners();
  }
  
  setupEventListeners() {
    document.querySelectorAll('input[name="parser_mode"]').forEach(radio => {
      radio.addEventListener('change', (e) => {
        const tagControls = document.getElementById('tagControls');
        if (tagControls) {
          const shouldShow = e.target.value === 'custom';
          
          if (shouldShow) {
            tagControls.style.display = 'block';
            tagControls.classList.add('fade-in');
          } else {
            tagControls.classList.remove('fade-in');
            setTimeout(() => {
              tagControls.style.display = 'none';
            }, 300);
          }
        }
        // Immediately update the visible mode label
        this.updateModeDisplay(e.target.value);
      });
    });
  }
  
  async loadSettings() {
    try {
      const response = await fetch('/parser-settings');
      const settings = await response.json();
      
      const mode = settings.mode || 'default';
      this.updateModeDisplay(mode);
      
      AppState.includeSet = new Set((settings.include_tags || []).map(t => String(t).toLowerCase()));
      AppState.excludeSet = new Set((settings.exclude_tags || []).map(t => String(t).toLowerCase()));
      AppState.allTags = new Set([...AppState.includeSet, ...AppState.excludeSet]);
      AppState.allTags.add('first_message');
      
      const tagControls = document.getElementById('tagControls');
      if (tagControls) {
        tagControls.style.display = mode === 'custom' ? 'block' : 'none';
      }
      
      this.renderChips();
      
      if (mode === 'custom' && AppState.allTags.size === 1) {
        await this.detectTagsLatest();
      }
      
    } catch (error) {
      console.error('Failed to load parser settings:', error);
      notifications.show('Failed to load parser settings', 'error');
    }
  }
  
  updateModeDisplay(mode) {
    const modeValueEl = document.getElementById('parser_mode_val');
    if (modeValueEl) {
      modeValueEl.textContent = mode.charAt(0).toUpperCase() + mode.slice(1);
      modeValueEl.classList.add('pulse-once');
      setTimeout(() => modeValueEl.classList.remove('pulse-once'), 600);
    }
    
    document.querySelectorAll('input[name="parser_mode"]').forEach(radio => {
      radio.checked = radio.value === mode;
    });
  }
  
  renderChips() {
    const container = document.getElementById('tagChips');
    if (!container) return;
    
    container.innerHTML = '';
    
    const sortedTags = Array.from(AppState.allTags).sort((a, b) => a.localeCompare(b));
    
    sortedTags.forEach((tag, index) => {
      const chip = document.createElement('div');
      chip.className = 'tag-chip';
      chip.textContent = tag;
      chip.title = 'Click to toggle: Include ↔ Exclude';
      
      if (AppState.includeSet.has(tag)) {
        chip.classList.add('include');
      } else {
        chip.classList.add('exclude');
        if (!AppState.excludeSet.has(tag)) AppState.excludeSet.add(tag);
      }
      
      chip.addEventListener('click', () => this.cycleTagState(tag, chip));
      chip.addEventListener('mouseenter', () => this.highlightFilesForTag(tag));
      chip.addEventListener('mouseleave', () => this.clearFileHighlights());
      
      chip.style.animationDelay = `${index * 30}ms`;
      chip.classList.add('fade-in-scale');
      
      container.appendChild(chip);
    });
  }
  
  cycleTagState(tag, chip) {
    if (AppState.includeSet.has(tag)) {
      // switch to exclude
      AppState.includeSet.delete(tag);
      AppState.excludeSet.add(tag);
      chip.className = 'tag-chip exclude';
      this.animateChipChange(chip);
    } else {
      // switch to include
      AppState.excludeSet.delete(tag);
      AppState.includeSet.add(tag);
      chip.className = 'tag-chip include';
      this.animateChipChange(chip);
    }
  }
  
  animateChipChange(chip) {
    chip.style.transform = 'scale(1.1)';
    setTimeout(() => {
      chip.style.transform = '';
    }, 200);
  }
  
  addTag(tagName) {
    const tag = (tagName || '').trim().toLowerCase();
    if (!tag) return;
    
    if (!AppState.allTags.has(tag)) {
      AppState.allTags.add(tag);
      // Default to exclude
      AppState.excludeSet.add(tag);
      this.renderChips();
      notifications.show(`Added tag: ${tag}`, 'success');
    } else {
      notifications.show('Tag already exists', 'info');
    }
  }
  
  toggleAllTags() {
    const button = document.getElementById('toggleAllBtn');
    
    if (AppState.toggleAllState === 'select') {
      AppState.includeSet = new Set(AppState.allTags);
      AppState.excludeSet.clear();
      AppState.toggleAllState = 'exclude';
      if (button) button.textContent = 'Exclude All';
    } else {
      AppState.excludeSet = new Set(AppState.allTags);
      AppState.includeSet.clear();
      AppState.toggleAllState = 'select';
      if (button) button.textContent = 'Include All';
    }
    
    this.renderChips();
  }
  
  clearAllTags() {
    AppState.includeSet.clear();
    AppState.excludeSet = new Set(AppState.allTags);
    AppState.toggleAllState = 'select';
    const button = document.getElementById('toggleAllBtn');
    if (button) button.textContent = 'Select All';
    this.renderChips();
    notifications.show('Set all tags to Exclude', 'info');
  }

  highlightFilesForTag(tagRaw) {
    const tag = String(tagRaw).toLowerCase();
    const scope = new Set(AppState.tagDetectScope || []);
    const filesLower = (AppState.tagToFilesLower && AppState.tagToFilesLower[tag]) || [];
    let setToHighlight = new Set(filesLower);
    if (scope.size > 0) {
      setToHighlight = new Set(filesLower.filter(f => scope.has(f)));
    }
    document.querySelectorAll('#logs .log-item').forEach(item => {
      const name = (item.getAttribute('data-name') || '').toLowerCase();
      if (setToHighlight.has(name)) {
        item.classList.add('highlight');
        const fn = item.querySelector('.log-filename');
        if (fn) fn.style.textDecoration = 'underline';
      } else {
        item.classList.remove('highlight');
        const fn = item.querySelector('.log-filename');
        if (fn) fn.style.textDecoration = '';
      }
    });
  }

  clearFileHighlights() {
    document.querySelectorAll('#logs .log-item').forEach(item => {
      item.classList.remove('highlight');
      const fn = item.querySelector('.log-filename');
      if (fn) fn.style.textDecoration = '';
    });
  }
  
  async detectTagsLatest() {
    try {
      const response = await fetch('/parser-tags?mode=latest');
      const data = await response.json();
      
      const tags = (data.tags || []).map(t => String(t).toLowerCase());
      tags.forEach(tag => {
        if (!AppState.allTags.has(tag)) {
          AppState.allTags.add(tag);
        }
      });
      
      AppState.allTags.add('first_message');
      
      const tagControls = document.getElementById('tagControls');
      if (tagControls) {
        tagControls.style.display = 'block';
      }
      
      this.renderChips();
      notifications.show(`Detected ${tags.length} tags`, 'success');
      
    } catch (error) {
      console.error('Failed to detect tags:', error);
      notifications.show('Failed to detect tags', 'error');
    }
  }

  openTagDetectModal() {
    // Build list from AppState.logs
    const container = document.getElementById('tagDetectList');
    const modal = document.getElementById('tagDetectModal');
    if (!container || !modal) return;
    this._tagDetectSelection = new Set();
    const logs = AppState.logs || [];
    if (!logs.length) {
      container.innerHTML = '<div class="empty-state"><p>No logs available.</p></div>';
    } else {
      const items = logs.map(name => `
        <label class="detect-item" style="display:block; margin-bottom:6px;">
          <input type="checkbox" data-name="${this.escapeHtml ? this.escapeHtml(name) : name}"> 
          <span>${name}</span>
        </label>
      `).join('');
      container.innerHTML = `<div class="detect-list" style="display:block;">${items}</div>`;
    }
    modal.style.display = 'flex';
    requestAnimationFrame(() => modal.classList.add('show'));
  }

  closeTagDetectModal() {
    const modal = document.getElementById('tagDetectModal');
    if (!modal) return;
    modal.classList.remove('show');
    setTimeout(() => modal.style.display = 'none', 200);
  }

  selectAllTagDetect() {
    const container = document.getElementById('tagDetectList');
    if (!container) return;
    container.querySelectorAll('input[type="checkbox"]').forEach(chk => chk.checked = true);
  }

  clearAllTagDetect() {
    const container = document.getElementById('tagDetectList');
    if (!container) return;
    container.querySelectorAll('input[type="checkbox"]').forEach(chk => chk.checked = false);
  }

  async confirmTagDetect() {
    const container = document.getElementById('tagDetectList');
    if (!container) return;
    const picked = [];
    container.querySelectorAll('input[type="checkbox"]').forEach(chk => {
      if (chk.checked) picked.push(chk.getAttribute('data-name'));
    });
    if (!picked.length) {
      notifications.show('Select at least one log', 'info');
      return;
    }
    try {
      const q = encodeURIComponent(picked.join(','));
      const response = await fetch(`/parser-tags?files=${q}`);
      const data = await response.json();
      const tags = (data.tags || []).map(t => String(t).toLowerCase());
      tags.forEach(tag => {
        if (!AppState.allTags.has(tag)) {
          AppState.allTags.add(tag);
        }
      });
      // Save mappings to AppState for exclusive filtering
      // Normalize mappings to lower-case file names for robust matching
      const byTag = data.by_tag || {};
      const norm = {};
      Object.keys(byTag).forEach(tag => {
        norm[tag.toLowerCase()] = (byTag[tag] || []).map(f => String(f).toLowerCase());
      });
      AppState.tagToFilesLower = norm;
      AppState.tagDetectScope = (data.files || []).map(n => String(n).toLowerCase());
      AppState.tagDetectScopeOriginal = (data.files || []).slice();
      this.renderChips();
      this.closeTagDetectModal();
      notifications.show(`Detected ${tags.length} tags`, 'success');
    } catch (e) {
      notifications.show('Failed to detect tags', 'error');
    }
  }
  
  async saveSettings() {
    const modeRadio = Array.from(document.querySelectorAll('input[name="parser_mode"]'))
      .find(r => r.checked);
    const mode = modeRadio ? modeRadio.value : 'default';
    
    const payload = {
      mode,
      include_tags: Array.from(AppState.includeSet),
      exclude_tags: Array.from(AppState.excludeSet)
    };
    
    try {
      const response = await fetch('/parser-settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      if (response.ok) {
        notifications.show('Parser settings saved', 'success');
        await this.loadSettings();
      } else {
        notifications.show('Failed to save settings', 'error');
      }
      
    } catch (error) {
      console.error('Error saving parser settings:', error);
      notifications.show('Error saving settings', 'error');
    }
  }
  
  async rewriteParsed() {
    await this.saveSettings();
    
    try {
      const response = await fetch('/parser-rewrite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode: 'all' })
      });
      
      if (response.ok) {
        const data = await response.json();
        notifications.show(`Rewrote ${data.rewritten} file(s)`, 'success');
      } else {
        notifications.show('Rewrite failed', 'error');
      }
      
    } catch (error) {
      console.error('Error rewriting logs:', error);
      notifications.show('Error rewriting logs', 'error');
    }
  }
}


class UIController {
  constructor() {
    this.setupEventListeners();
    this.loadPreferences();
  }
  
  setupEventListeners() {
    const sidebarToggle = document.getElementById('toggleSidebarBtn');
    if (sidebarToggle) {
      sidebarToggle.addEventListener('click', () => this.toggleSidebar());
    }
    
    const densityToggle = document.getElementById('toggleDensityBtn');
    if (densityToggle) {
      densityToggle.addEventListener('click', () => this.toggleDensity());
    }
    
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
      refreshBtn.addEventListener('click', () => this.refreshAll());
    }
    
    const logFilter = document.getElementById('logFilter');
    if (logFilter) {
      logFilter.addEventListener('input', debounce(() => {
        dataManager.renderLogs(AppState.logs);
      }, Config.DEBOUNCE_DELAY));
    }
    
    const addTagInput = document.getElementById('newTagInput');
    if (addTagInput) {
      addTagInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
          parserController.addTag(addTagInput.value);
          addTagInput.value = '';
        }
      });
    }
  }
  
  toggleSidebar() {
    const sidebar = document.querySelector('.sidebar');
    sidebar.classList.toggle('collapsed');
    
    localStorage.setItem('sidebarCollapsed', 
      sidebar.classList.contains('collapsed') ? '1' : '0');
    
    const button = document.getElementById('toggleSidebarBtn');
    if (button) {
      button.style.transform = 'scale(0.9)';
      setTimeout(() => {
        button.style.transform = '';
      }, 200);
    }
  }
  
  toggleDensity() {
    document.body.classList.toggle('compact');
    
    localStorage.setItem('densityCompact', 
      document.body.classList.contains('compact') ? '1' : '0');
    
    const button = document.getElementById('toggleDensityBtn');
    if (button) {
      button.textContent = document.body.classList.contains('compact') ? 'Normal' : 'Compact';
      
      button.style.transform = 'scale(0.9)';
      setTimeout(() => {
        button.style.transform = '';
      }, 200);
    }
  }
  
  async refreshAll() {
    const button = document.getElementById('refreshBtn');
    if (button) {
      button.classList.add('spinning');
    }
    
    await Promise.all([
      dataManager.updateStats(),
      dataManager.updateEndpoints()
    ]);
    
    if (button) {
      setTimeout(() => {
        button.classList.remove('spinning');
      }, 500);
    }
    
    notifications.show('Data refreshed', 'success');
  }
  
  loadPreferences() {
    try {
      if (localStorage.getItem('sidebarCollapsed') === '1') {
        document.querySelector('.sidebar')?.classList.add('collapsed');
      }
      
      if (localStorage.getItem('densityCompact') === '1') {
        document.body.classList.add('compact');
        const button = document.getElementById('toggleDensityBtn');
        if (button) button.textContent = 'Normal';
      }
      
    } catch (error) {
      console.error('Error loading preferences:', error);
    }
  }

  openRewriteOptions() {
    const modal = document.getElementById('writeModal');
    if (!modal) return;
    modal.style.display = 'flex';
    requestAnimationFrame(() => modal.classList.add('show'));
  }

  closeRewriteOptions() {
    const modal = document.getElementById('writeModal');
    if (!modal) return;
    modal.classList.remove('show');
    setTimeout(() => modal.style.display = 'none', 200);
  }

  async rewriteLatest() {
    this.closeRewriteOptions();
    // Ensure latest include/exclude settings are persisted before writing
    try { await parserController.saveSettings(); } catch (_) {}
    try {
      const res = await fetch('/parser-rewrite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode: 'latest' })
      });
      if (res.ok) {
        const data = await res.json();
        notifications.show(`Wrote ${data.rewritten} file(s)`, 'success');
        refreshAll();
      } else {
        notifications.show('Rewrite failed', 'error');
      }
    } catch (e) {
      notifications.show('Rewrite failed', 'error');
    }
  }

  startCustomRewriteSelection() {
    this.closeRewriteOptions();
    AppState.selectingLogs = true;
    AppState.selectedLogs = new Set();

    // Advanced filter: if include mode with exclusive tags picked, narrow list
    const modeVal = (document.querySelector('input[name="parser_mode"]:checked')?.value || 'default');
    const modeIsInclude = (modeVal === 'custom') && (AppState.includeSet && AppState.includeSet.size > 0);
    // Start from the detection scope if present, otherwise all logs
    let baseList = (AppState.tagDetectScopeOriginal && AppState.tagDetectScopeOriginal.length)
      ? AppState.tagDetectScopeOriginal.slice()
      : AppState.logs.slice();
    let toShow = baseList.slice();
    if (modeIsInclude && AppState.tagToFilesLower) {
      // Narrow to files that match at least one included tag AND that tag is exclusive
      const includeTags = Array.from(AppState.includeSet || []).map(t => String(t).toLowerCase());
      const totalLogsLower = new Set(baseList.map(n => n.toLowerCase()));
      const eligibleFilesLower = new Set();
      includeTags.forEach(tag => {
        const files = AppState.tagToFilesLower[tag] || [];
        if (files.length > 0 && files.length < totalLogsLower.size) {
          files.forEach(f => eligibleFilesLower.add(f));
        }
      });
      if (eligibleFilesLower.size > 0) {
        toShow = toShow.filter(n => eligibleFilesLower.has(n.toLowerCase()));
      }
    }
    dataManager.renderLogs(toShow, false);
    dataManager.updateSelectionToolbar();
  }

  toggleSelectAllLogs() {
    if (!AppState.selectingLogs) return;
    const total = AppState.logs.length;
    const allSelected = (AppState.selectedLogs?.size || 0) === total;
    if (allSelected) {
      AppState.selectedLogs.clear();
    } else {
      AppState.selectedLogs = new Set(AppState.logs);
    }
    dataManager.renderLogs(AppState.logs, false);
    dataManager.updateSelectionToolbar();
  }

  async rewriteSelectedLogs() {
    const files = Array.from(AppState.selectedLogs || []);
    if (!files.length) {
      notifications.show('No files selected', 'info');
      return;
    }
    try {
      try { await parserController.saveSettings(); } catch (_) {}
      const res = await fetch('/parser-rewrite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode: 'custom', files })
      });
      if (res.ok) {
        const data = await res.json();
        notifications.show(`Wrote ${data.rewritten} file(s)`, 'success');
        this.cancelLogSelection();
        refreshAll();
      } else {
        notifications.show('Rewrite failed', 'error');
      }
    } catch (e) {
      notifications.show('Rewrite failed', 'error');
    }
  }

  cancelLogSelection() {
    AppState.selectingLogs = false;
    AppState.selectedLogs = new Set();
    dataManager.renderLogs(AppState.logs, false);
    dataManager.updateSelectionToolbar();
  }
}


window.copyText = copyText;
window.closeModal = () => new Modal().hide();
window.copyModal = async () => {
  const content = document.getElementById('modalBody')?.textContent || '';
  try {
    await navigator.clipboard.writeText(content);
    notifications.show('Copied to clipboard', 'success');
  } catch (error) {
    notifications.show('Failed to copy', 'error');
  }
};
window.saveParserSettings = () => parserController.saveSettings();
window.rewriteParsed = () => parserController.rewriteParsed();
window.openWriteOptions = () => uiController.openRewriteOptions();
window.closeWriteOptions = () => uiController.closeRewriteOptions();
window.writeLatest = () => uiController.rewriteLatest();
window.startCustomWriteSelection = () => uiController.startCustomRewriteSelection();
window.toggleSelectAllLogs = () => uiController.toggleSelectAllLogs();
window.rewriteSelectedLogs = () => uiController.rewriteSelectedLogs();
window.cancelLogSelection = () => uiController.cancelLogSelection();
window.toggleAllTags = () => parserController.toggleAllTags();
window.clearAllTags = () => parserController.clearAllTags();
window.detectTagsLatest = () => parserController.detectTagsLatest();
window.detectTagsFromLogs = () => parserController.openTagDetectModal();
window.closeTagDetect = () => parserController.closeTagDetectModal();
window.confirmTagDetect = () => parserController.confirmTagDetect();
window.selectAllTagDetect = () => parserController.selectAllTagDetect();
window.clearAllTagDetect = () => parserController.clearAllTagDetect();
window.addTagFromInput = () => {
  const input = document.getElementById('newTagInput');
  if (input) {
    parserController.addTag(input.value);
    input.value = '';
  }
};
window.refreshAll = () => uiController.refreshAll();


let navigationController, dataManager, parserController, uiController;

document.addEventListener('DOMContentLoaded', () => {
  document.body.classList.add('loading');
  
  navigationController = new NavigationController();
  dataManager = new DataManager();
  parserController = new ParserController();
  uiController = new UIController();
  
  Promise.all([
    dataManager.updateStats(),
    dataManager.updateEndpoints()
  ]).then(() => {
    document.body.classList.remove('loading');
  });
  
  AppState.refreshInterval = setInterval(() => {
    dataManager.updateStats(true);
    dataManager.updateEndpoints(true);
  }, Config.REFRESH_INTERVAL);
  
  const style = document.createElement('style');
  style.textContent = `
    .fade-in-up {
      animation: fadeInUp 0.5s var(--ease-expo) forwards;
    }
    
    .fade-in-scale {
      animation: fadeInScale 0.3s var(--ease-bounce) forwards;
    }
    
    .fade-in {
      animation: fadeIn 0.3s var(--ease-smooth) forwards;
    }
    
    .pulse-once {
      animation: pulseOnce 0.6s var(--ease-bounce);
    }
    
    .spinning {
      animation: spin 1s linear infinite;
    }
    
    .updating {
      animation: pulse 0.3s var(--ease-smooth);
    }
    
    .copied {
      animation: copiedPulse 0.5s var(--ease-bounce);
    }
    
    @keyframes fadeInUp {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    
    @keyframes fadeInScale {
      from {
        opacity: 0;
        transform: scale(0.8);
      }
      to {
        opacity: 1;
        transform: scale(1);
      }
    }
    
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    
    @keyframes pulseOnce {
      0%, 100% { transform: scale(1); }
      50% { transform: scale(1.05); }
    }
    
    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
    
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.6; }
    }
    
    @keyframes copiedPulse {
      0% { 
        background-color: rgba(0, 212, 255, 0.1);
        border-color: var(--accent-primary);
      }
      100% {
        background-color: rgba(255, 255, 255, 0.02);
        border-color: var(--border-default);
      }
    }
    
    /* JSON Syntax Highlighting */
    .json-key { color: var(--accent-primary); }
    .json-string { color: var(--accent-success); }
    .json-number { color: var(--accent-warning); }
    .json-boolean { color: var(--accent-tertiary); }
    .json-null { color: var(--text-muted); }
  `;
  document.head.appendChild(style);
});

window.addEventListener('beforeunload', () => {
  if (AppState.refreshInterval) {
    clearInterval(AppState.refreshInterval);
  }
});
