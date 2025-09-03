// Centralized DOM cache to avoid repeated queries
const DOM = {};
const initDOMCache = () => {
  const ids = [
    'requestCount', 'logs', 'logFilter', 'modalTitle', 'modalBody', 'logModal',
    'endpointCloudflare', 'endpointLocal', 'openCloudflareBtn', 'openLocalBtn',
    'notification', 'parser_mode_val', 'tagControls', 'tagChips', 'newTagInput',
    'toggleAllBtn', 'selectionToolbar', 'toggleSelectAllBtn', 'modalBackBtn',
    'tagDetectModal', 'tagDetectList', 'writeModal', 'refreshBtn', 'toggleSidebarBtn',
    'toggleDensityBtn', 'totalLogs', 'parsedTotal'
  ];
  ids.forEach(id => { DOM[id] = document.getElementById(id); });
};

// Centralized state with cleaner structure
const State = {
  includeSet: new Set(),
  excludeSet: new Set(),
  allTags: new Set(),
  logs: [],
  logMeta: new Map(), // name -> {mtime, size}
  selectedLogs: new Set(),
  selectingLogs: false,
  tagToFilesLower: {},
  tagDetectScope: [],
  refreshTimer: null,
  caches: {
    json: new Map(),
    parsedList: new Map(),
    parsedContent: new Map()
  }
};

const Config = {
  REFRESH_INTERVAL: 5000,
  NOTIFICATION_DURATION: 3000,
  DEBOUNCE_DELAY: 300,
  MAX_LOGS: 100,
  CACHE_LIMITS: { json: 50, parsedContent: 80 }
};

// Unified error handler
const handleError = (message, error = null) => {
  console.error(message, error);
  notifications.show(message, 'error');
};

// Simplified fetch wrapper
const api = {
  async get(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res;
  },
  async getJson(url) {
    return (await this.get(url)).json();
  },
  async getText(url) {
    return (await this.get(url)).text();
  },
  async post(url, data) {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    if (!res.ok) {
      const error = await res.json().catch(() => ({ error: 'Request failed' }));
      throw new Error(error.error || 'Request failed');
    }
    return res.json();
  }
};

// Simplified element creator
const createElement = (tag, attrs = {}, children = []) => {
  const el = document.createElement(tag);
  Object.entries(attrs).forEach(([k, v]) => {
    if (k === 'class') el.className = v;
    else if (k === 'text') el.textContent = v;
    else if (k === 'html') el.innerHTML = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v);
  });
  children.forEach(c => c && el.appendChild(c));
  return el;
};

// Unified animation utility
const animate = {
  pulse(el) {
    el.classList.add('pulse-once');
    setTimeout(() => el.classList.remove('pulse-once'), 600);
  },
  scale(el, temp = true) {
    el.style.transform = 'scale(1.1)';
    if (temp) setTimeout(() => { el.style.transform = ''; }, 200);
  },
  fadeIn(el, className = 'fade-in') {
    el.classList.add(className);
  },
  spin(el, duration = 500) {
    el.classList.add('spinning');
    setTimeout(() => el.classList.remove('spinning'), duration);
  }
};

// Simplified cache manager
class CacheManager {
  constructor(limit) {
    this.cache = new Map();
    this.limit = limit;
  }
  
  set(key, value) {
    if (this.cache.has(key)) this.cache.delete(key);
    this.cache.set(key, value);
    while (this.cache.size > this.limit) {
      this.cache.delete(this.cache.keys().next().value);
    }
    return value;
  }
  
  get(key) { return this.cache.get(key); }
  has(key) { return this.cache.has(key); }
  delete(key) { this.cache.delete(key); }
  clear() { this.cache.clear(); }
}

// Simplified notification manager
class NotificationManager {
  constructor() {
    this.queue = [];
    this.showing = false;
  }
  
  show(message, type = 'success') {
    this.queue.push({ message, type });
    if (!this.showing) this.processNext();
  }
  
  processNext() {
    if (!this.queue.length) return;
    this.showing = true;
    const { message, type } = this.queue.shift();
    
    if (!DOM.notification) return;
    const msgEl = DOM.notification.querySelector('.notification-message');
    const iconEl = DOM.notification.querySelector('.notification-icon');
    
    if (msgEl) msgEl.textContent = message;
    if (iconEl) {
      iconEl.style.color = `var(--accent-${type === 'error' ? 'danger' : type === 'warning' ? 'warning' : 'primary'})`;
    }
    
    DOM.notification.classList.add('show');
    setTimeout(() => {
      DOM.notification.classList.remove('show');
      this.showing = false;
      setTimeout(() => this.processNext(), 300);
    }, Config.NOTIFICATION_DURATION);
  }
}

const notifications = new NotificationManager();

// Utility functions
const debounce = (fn, delay) => {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn(...args), delay);
  };
};

const formatNumber = n => n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
const getRelativeTime = () => new Date().toTimeString().slice(0, 5);
const escapeHtml = text => {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
};

// Simplified Modal class
class Modal {
  constructor() {
    this.el = DOM.logModal;
    this.title = DOM.modalTitle;
    this.body = DOM.modalBody;
    this.backBtn = DOM.modalBackBtn;
  }
  
  show(title, content, isHtml = false) {
    if (!this.el || !this.title || !this.body) return;
    
    this.title.textContent = title;
    if (isHtml) {
      this.body.innerHTML = content;
    } else {
      this.body.textContent = content;
      if (content.trim().match(/^[\[{]/)) {
        try {
          const parsed = JSON.parse(content);
          this.body.innerHTML = this.syntaxHighlight(JSON.stringify(parsed, null, 2));
        } catch {}
      }
    }
    
    this.el.style.display = 'flex';
    requestAnimationFrame(() => this.el.classList.add('show'));
  }
  
  hide() {
    if (!this.el) return;
    this.el.classList.remove('show');
    this.el.style.display = 'none';
  }
  
  setBack(handler) {
    if (!this.backBtn) return;
    if (handler) {
      this.backBtn.style.display = '';
      this.backBtn.onclick = e => { e.preventDefault(); handler(); };
    } else {
      this.backBtn.style.display = 'none';
      this.backBtn.onclick = null;
    }
  }
  
  syntaxHighlight(json) {
    return json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, 
        match => {
          let cls = 'number';
          if (/^"/.test(match)) cls = /:$/.test(match) ? 'key' : 'string';
          else if (/true|false/.test(match)) cls = 'boolean';
          else if (/null/.test(match)) cls = 'null';
          return `<span class="json-${cls}">${match}</span>`;
        });
  }
}

// Main data manager (simplified)
class DataManager {
  constructor() {
    this.jsonCache = new CacheManager(Config.CACHE_LIMITS.json);
    this.parsedListCache = new CacheManager(100);
    this.parsedContentCache = new CacheManager(Config.CACHE_LIMITS.parsedContent);
  }
  
  async updateStats(silent = false) {
    try {
      const data = await api.getJson('/logs');
      const total = data.total || 0; // since startup
      
      if (DOM.requestCount) {
        const current = parseInt(DOM.requestCount.textContent.replace(/,/g, '') || '0');
        if (current !== total) {
          this.animateCounter(DOM.requestCount, current, total);
        }
      }
      
      State.logs = data.logs || [];
      // Build metadata map for timestamps and sizes
      State.logMeta = new Map();
      if (Array.isArray(data.items)) {
        data.items.forEach(it => {
          if (it && it.name) {
            State.logMeta.set(it.name, { mtime: Number(it.mtime) || 0, size: Number(it.size) || 0 });
          }
        });
      }

      // Update additional metrics if present
      if (DOM.totalLogs && typeof data.total_all === 'number') {
        const cur = parseInt(DOM.totalLogs.textContent.replace(/,/g, '') || '0');
        if (cur !== data.total_all) this.animateCounter(DOM.totalLogs, cur, data.total_all);
      }
      if (DOM.parsedTotal && typeof data.parsed_total === 'number') {
        const cur = parseInt(DOM.parsedTotal.textContent.replace(/,/g, '') || '0');
        if (cur !== data.parsed_total) this.animateCounter(DOM.parsedTotal, cur, data.parsed_total);
      }
      this.renderLogs(!silent);
      // Opportunistic prefetch to make first opens instant
      this.schedulePrefetch(State.logs);
    } catch (error) {
      handleError('Failed to load data', error);
    }
  }
  
  animateCounter(el, start, end, duration = 500) {
    const range = Math.abs(end - start);
    if (range === 0) {
      el.textContent = formatNumber(end);
      animate.pulse(el);
      return;
    }
    const increment = end > start ? 1 : -1;
    const stepTime = Math.max(10, Math.floor(duration / range));
    let current = start;
    const timer = setInterval(() => {
      current += increment;
      el.textContent = formatNumber(current);
      if (current === end) {
        clearInterval(timer);
        animate.pulse(el);
      }
    }, stepTime);
  }
  
  renderLogs(animated = false) {
    if (!DOM.logs) return;
    
    const filter = (DOM.logFilter?.value || '').toLowerCase();
    const filtered = State.logs.filter(name => !filter || name.toLowerCase().includes(filter))
      .slice(0, Config.MAX_LOGS);
    
    if (!filtered.length) {
      DOM.logs.innerHTML = '<div class="empty-state"><p>Waiting for requests...</p></div>';
      return;
    }
    
    DOM.logs.innerHTML = '';
    const fragment = document.createDocumentFragment();
    
    filtered.forEach((name, i) => {
      const item = this.createLogItem(name, animated ? i : null);
      fragment.appendChild(item);
    });
    
    DOM.logs.appendChild(fragment);
  }

  // Render from a provided list (used for selection filtering)
  renderLogsFrom(list, animated = false) {
    if (!DOM.logs) return;
    const filtered = (list || []).slice(0, Config.MAX_LOGS);
    if (!filtered.length) {
      DOM.logs.innerHTML = '<div class="empty-state"><p>Waiting for requests...</p></div>';
      return;
    }
    DOM.logs.innerHTML = '';
    const fragment = document.createDocumentFragment();
    filtered.forEach((name, i) => {
      const item = this.createLogItem(name, animated ? i : null);
      fragment.appendChild(item);
    });
    DOM.logs.appendChild(fragment);
  }
  
  createLogItem(name, animIndex) {
    const item = createElement('div', { 
      class: 'log-item',
      'data-name': name
    });
    
    if (animIndex !== null) {
      item.style.animationDelay = `${animIndex * 20}ms`;
      animate.fadeIn(item, 'fade-in-up');
    }
    
    if (State.selectingLogs) {
      const span = createElement('span', { class: 'log-filename', text: name });
      const meta = State.logMeta.get(name);
      const time = createElement('span', { class: 'log-time', text: this.formatMTime(meta?.mtime) });
      item.appendChild(span);
      item.appendChild(time);
      item.classList.add('selectable');
      
      if (State.selectedLogs.has(name)) {
        item.classList.add('active');
      }
      
      item.onclick = e => this.toggleLogSelection(e, name, item);
      return item;
    }
    
    const left = createElement('div', { class: 'log-left' });
    const nameSpan = createElement('span', { class: 'log-filename', text: name });
    const txtBtn = createElement('button', { 
      class: 'mini-btn mini-txt-btn loud',
      text: 'TXT',
      onclick: e => { e.stopPropagation(); this.openParsedList(name); }
    });
    const renameBtn = createElement('button', {
      class: 'icon-btn mini-rename-btn',
      text: '✎',
      onclick: e => this.startInlineRename(e, item, name)
    });
    
    left.appendChild(nameSpan);
    left.appendChild(txtBtn);
    left.appendChild(renameBtn);
    
    const meta = State.logMeta.get(name);
    const time = createElement('span', { class: 'log-time', text: this.formatMTime(meta?.mtime) });
    item.appendChild(left);
    item.appendChild(time);
    
    item.onclick = () => this.openLog(name);
    return item;
  }

  formatMTime(mtime) {
    if (!mtime || Number.isNaN(mtime)) return '';
    try {
      const d = new Date(mtime * 1000);
      // HH:MM if today, otherwise YYYY-MM-DD HH:MM
      const now = new Date();
      const pad = n => String(n).padStart(2, '0');
      const hhmm = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
      if (d.toDateString() === now.toDateString()) return hhmm;
      return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${hhmm}`;
    } catch { return ''; }
  }
  
  toggleLogSelection(e, name, el) {
    e.stopPropagation();
    if (State.selectedLogs.has(name)) {
      State.selectedLogs.delete(name);
      el.classList.remove('active');
    } else {
      State.selectedLogs.add(name);
      el.classList.add('active');
    }
    this.updateSelectionToolbar();
  }
  
  updateSelectionToolbar() {
    if (!DOM.selectionToolbar) return;
    DOM.selectionToolbar.style.display = State.selectingLogs ? 'flex' : 'none';
    
    if (DOM.toggleSelectAllBtn) {
      const count = State.selectedLogs.size;
      const total = State.logs.length;
      DOM.toggleSelectAllBtn.textContent = count === total ? 'Deselect All' : 'Select All';
    }
  }
  
  async openLog(name) {
    const modal = new Modal();
    const cached = this.jsonCache.get(name);
    
    if (cached) {
      modal.show(name, cached);
    } else {
      modal.show(name, 'Loading…');
    }
    
    try {
      const content = await api.getText(`/logs/${encodeURIComponent(name)}`);
      this.jsonCache.set(name, content);
      modal.show(name, content);
    } catch (error) {
      if (!cached) handleError('Failed to load log', error);
    }
  }
  
  async openParsedList(name) {
    try {
      let data = this.parsedListCache.get(name);
      if (!data) {
        data = await api.getJson(`/logs/${encodeURIComponent(name)}/parsed`);
        this.parsedListCache.set(name, data);
      }
      
      const versions = data.versions || [];
      if (!versions.length) {
        notifications.show('No parsed TXT versions yet', 'info');
        return;
      }
      
      const modal = new Modal();
      const content = createElement('div', { class: 'version-picker' }, [
        createElement('div', { class: 'version-header', text: 'Parsed TXT Versions' }),
        createElement('ul', { class: 'version-list' }, 
          versions.map(v => this.createVersionItem(name, v, data.latest))
        )
      ]);
      
      modal.show(`${name} — TXT`, '', true);
      DOM.modalBody.innerHTML = '';
      DOM.modalBody.appendChild(content);
      modal.setBack(() => this.openParsedList(name));

      // Prefetch all listed parsed contents to make first click instant
      try {
        const ids = versions.map(v => v.file);
        await this.prefetchParsedContentList(name, ids);
      } catch (e) { /* noop */ }
      
    } catch (error) {
      handleError('Failed to load parsed versions', error);
    }
  }
  
  createVersionItem(logName, version, latest) {
    const isLatest = latest && version.file === latest;
    const meta = `${isLatest ? 'Latest ' : ''}${this.formatDate(version.mtime)} • ${Math.max(1, Math.round((version.size || 0) / 1024))} KB`;
    
    return createElement('li', {}, [
      createElement('div', { class: 'version-left' }, [
        createElement('button', {
          class: 'version-item',
          text: version.file,
          onclick: () => this.openParsedContent(logName, version.file)
        }),
        createElement('button', {
          class: 'icon-btn version-rename',
          text: '✎',
          onclick: e => this.renameParsedFile(e, logName, version.file)
        })
      ]),
      createElement('span', { class: 'meta', text: meta })
    ]);
  }
  
  async openParsedContent(name, id) {
    const modal = new Modal();
    const key = `${name}|${id}`;
    const cached = this.parsedContentCache.get(key);
    
    const title = `${name} — ${id}`;
    modal.show(title, cached || 'Loading…');
    modal.setBack(() => this.openParsedList(name));
    
    if (!cached) {
      try {
        const text = await api.getText(`/logs/${encodeURIComponent(name)}/parsed/${encodeURIComponent(id)}`);
        this.parsedContentCache.set(key, text);
        modal.show(title, text);
      } catch (error) {
        handleError('Failed to load parsed content', error);
      }
    }
  }
  
  async startInlineRename(e, item, name) {
    e.stopPropagation();
    const left = item.querySelector('.log-left');
    if (!left || left.querySelector('.inline-rename')) return;
    
    const elements = {
      name: left.querySelector('.log-filename'),
      txt: left.querySelector('.mini-txt-btn'),
      rename: left.querySelector('.mini-rename-btn')
    };
    
    Object.values(elements).forEach(el => el && (el.style.display = 'none'));
    
    const wrap = createElement('div', { class: 'inline-rename' });
    const input = createElement('input', { 
      class: 'copy-input rename-input',
      value: name,
      style: 'flex:1'
    });
    
    const cleanup = () => {
      left.removeChild(wrap);
      Object.values(elements).forEach(el => el && (el.style.display = ''));
    };
    
    wrap.appendChild(input);
    wrap.appendChild(createElement('button', {
      class: 'button button-secondary',
      text: 'Cancel',
      onclick: cleanup
    }));
    wrap.appendChild(createElement('button', {
      class: 'button',
      text: 'Save',
      onclick: async () => {
        const newName = input.value.trim();
        if (!newName || newName === name) {
          cleanup();
          return;
        }
        try {
          await api.post(`/logs/${encodeURIComponent(name)}/rename`, { new_name: newName });
          notifications.show('Log renamed', 'success');
          this.clearCachesFor(name);
          await this.updateStats();
        } catch (error) {
          handleError(error.message);
        }
        cleanup();
      }
    }));
    
    left.appendChild(wrap);
    setTimeout(() => { input.focus(); input.select(); }, 0);
    
    input.onkeydown = e => {
      if (e.key === 'Enter') wrap.querySelector('.button:not(.button-secondary)').click();
      if (e.key === 'Escape') wrap.querySelector('.button-secondary').click();
    };
  }
  
  async renameParsedFile(e, logName, fileName) {
    e.stopPropagation();
    const newName = prompt('New name:', fileName);
    if (!newName || newName === fileName) return;
    
    try {
      await api.post(`/logs/${encodeURIComponent(logName)}/parsed/rename`, {
        old: fileName,
        new: newName
      });
      notifications.show('File renamed', 'success');
      this.clearCachesFor(logName);
      this.openParsedList(logName);
    } catch (error) {
      handleError(error.message);
    }
  }
  
  clearCachesFor(name) {
    this.parsedListCache.delete(name);
    this.jsonCache.delete(name);
    const prefix = `${name}|`;
    [...this.parsedContentCache.cache.keys()]
      .filter(k => k.startsWith(prefix))
      .forEach(k => this.parsedContentCache.delete(k));
  }
  
  formatDate(unixSeconds) {
    if (!unixSeconds) return '';
    return new Date(unixSeconds * 1000).toISOString().slice(0, 19).replace('T', ' ');
  }
  
  async updateEndpoints(silent = false) {
    let cloudflareUrl = '';
    let localUrl = 'http://localhost:5000/openrouter-cc';
    
    try {
      const { url } = await api.getJson('/tunnel');
      cloudflareUrl = url ? `${url}/openrouter-cc` : '';
    } catch {}
    
    try {
      const { config } = await api.getJson('/health');
      localUrl = `http://localhost:${config?.port || 5000}/openrouter-cc`;
    } catch {}
    
    if (DOM.endpointCloudflare) {
      DOM.endpointCloudflare.value = cloudflareUrl || 'Not available';
      if (!silent) animate.pulse(DOM.endpointCloudflare);
    }
    
    if (DOM.endpointLocal) {
      DOM.endpointLocal.value = localUrl;
      if (!silent) animate.pulse(DOM.endpointLocal);
    }
    
    if (DOM.openCloudflareBtn) {
      DOM.openCloudflareBtn.style.pointerEvents = cloudflareUrl ? 'auto' : 'none';
      DOM.openCloudflareBtn.style.opacity = cloudflareUrl ? '1' : '0.5';
      DOM.openCloudflareBtn.href = cloudflareUrl || '#';
    }
    
    if (DOM.openLocalBtn) {
      DOM.openLocalBtn.href = localUrl.replace('/openrouter-cc', '/');
    }
  }

  // Background prefetch to speed up first opens
  schedulePrefetch(logs) {
    const run = () => this.prefetchForLogs(logs).catch(() => {});
    if (window.requestIdleCallback) {
      window.requestIdleCallback(run, { timeout: 300 });
    } else {
      setTimeout(run, 50);
    }
  }

  async prefetchForLogs(logs) {
    const JSON_COUNT = 10;
    const LIST_COUNT = 6;
    const top = (logs || []).slice(0, Math.max(JSON_COUNT, LIST_COUNT));
    const jsonTasks = top.slice(0, JSON_COUNT).map(name => async () => {
      if (this.jsonCache.has(name)) return;
      try {
        const txt = await api.getText(`/logs/${encodeURIComponent(name)}`);
        this.jsonCache.set(name, txt);
      } catch {}
    });
    const listTasks = top.slice(0, LIST_COUNT).map(name => async () => {
      let data = this.parsedListCache.get(name);
      try {
        if (!data) {
          data = await api.getJson(`/logs/${encodeURIComponent(name)}/parsed`);
          this.parsedListCache.set(name, data);
        }
        const latest = data?.latest;
        if (latest && !this.parsedContentCache.has(`${name}|${latest}`)) {
          const text = await api.getText(`/logs/${encodeURIComponent(name)}/parsed/${encodeURIComponent(latest)}`);
          this.parsedContentCache.set(`${name}|${latest}`, text);
        }
      } catch {}
    });
    await this._runLimited([...jsonTasks, ...listTasks], 3);
  }

  async prefetchParsedContentList(name, ids) {
    const tasks = (ids || []).map(id => async () => {
      const key = `${name}|${id}`;
      if (this.parsedContentCache.has(key)) return;
      try {
        const text = await api.getText(`/logs/${encodeURIComponent(name)}/parsed/${encodeURIComponent(id)}`);
        this.parsedContentCache.set(key, text);
      } catch {}
    });
    await this._runLimited(tasks, 3);
  }

  async _runLimited(tasks, concurrency = 3) {
    const queue = tasks.slice();
    const workers = new Array(Math.min(concurrency, queue.length)).fill(0).map(async () => {
      while (queue.length) {
        const task = queue.shift();
        try { await task(); } catch {}
      }
    });
    await Promise.all(workers);
  }
}

// Parser controller (simplified)
class ParserController {
  constructor() {
    this.tagDetectSelection = new Set();
  }
  
  async loadSettings() {
    try {
      const settings = await api.getJson('/parser-settings');
      const mode = settings.mode || 'default';
      
      State.includeSet.clear();
      State.excludeSet = new Set((settings.exclude_tags || []).map(t => t.toLowerCase()));
      State.allTags.clear();
      
      this.updateModeDisplay(mode);
      if (DOM.tagControls) {
        DOM.tagControls.style.display = mode === 'custom' ? 'block' : 'none';
      }
      
      this.renderChips();
    } catch (error) {
      handleError('Failed to load parser settings', error);
    }
  }
  
  updateModeDisplay(mode) {
    if (DOM.parser_mode_val) {
      DOM.parser_mode_val.textContent = mode.charAt(0).toUpperCase() + mode.slice(1);
      animate.pulse(DOM.parser_mode_val);
    }
    
    document.querySelectorAll('input[name="parser_mode"]').forEach(radio => {
      radio.checked = radio.value === mode;
    });
  }
  
  renderChips() {
    if (!DOM.tagChips) return;
    
    const fragment = document.createDocumentFragment();
    const sorted = [...State.allTags].sort();
    
    sorted.forEach((tag, i) => {
      const chip = createElement('div', {
        class: `tag-chip ${State.includeSet.has(tag) ? 'include' : State.excludeSet.has(tag) ? 'exclude' : ''}`,
        text: tag,
        title: 'Click to toggle: Include ↔ Exclude',
        onclick: () => this.cycleTagState(tag, chip),
        onmouseenter: () => this.highlightFilesForTag(tag),
        onmouseleave: () => this.clearFileHighlights()
      });
      
      chip.style.animationDelay = `${i * 30}ms`;
      animate.fadeIn(chip, 'fade-in-scale');
      fragment.appendChild(chip);
    });
    
    DOM.tagChips.innerHTML = '';
    DOM.tagChips.appendChild(fragment);
  }
  
  cycleTagState(tag, chip) {
    if (State.includeSet.has(tag)) {
      State.includeSet.delete(tag);
      State.excludeSet.add(tag);
      chip.className = 'tag-chip exclude';
    } else {
      State.excludeSet.delete(tag);
      State.includeSet.add(tag);
      chip.className = 'tag-chip include';
    }
    animate.scale(chip);
  }
  
  highlightFilesForTag(tag) {
    const files = new Set((State.tagToFilesLower[tag.toLowerCase()] || [])
      .filter(f => !State.tagDetectScope.length || State.tagDetectScope.includes(f)));
    
    document.querySelectorAll('#logs .log-item').forEach(item => {
      const name = (item.dataset.name || '').toLowerCase();
      const highlight = files.has(name);
      item.classList.toggle('highlight', highlight);
      const fn = item.querySelector('.log-filename');
      if (fn) fn.style.textDecoration = highlight ? 'underline' : '';
    });
  }
  
  clearFileHighlights() {
    document.querySelectorAll('#logs .log-item').forEach(item => {
      item.classList.remove('highlight');
      const fn = item.querySelector('.log-filename');
      if (fn) fn.style.textDecoration = '';
    });
  }
  
  async detectTags(mode = 'latest', files = null) {
    try {
      const url = mode === 'latest' ? '/parser-tags?mode=latest' : 
                  `/parser-tags?files=${encodeURIComponent(files.join(','))}`;
      const data = await api.getJson(url);
      
      const tags = (data.tags || []).map(t => t.toLowerCase());
      State.allTags = new Set([...tags, 'first_message']);
      
      const byTag = data.by_tag || {};
      State.tagToFilesLower = Object.fromEntries(
        Object.entries(byTag).map(([tag, files]) => [
          tag.toLowerCase(),
          files.map(f => f.toLowerCase())
        ])
      );
      
      State.tagDetectScope = (data.files || []).map(n => n.toLowerCase());
      
      if (DOM.tagControls) DOM.tagControls.style.display = 'block';
      this.renderChips();
      notifications.show(`Detected ${tags.length} tags`, 'success');
      
    } catch (error) {
      handleError('Failed to detect tags', error);
    }
  }
  
  async saveSettings() {
    const mode = document.querySelector('input[name="parser_mode"]:checked')?.value || 'default';
    
    try {
      await api.post('/parser-settings', {
        mode,
        exclude_tags: [...State.excludeSet]
      });
      notifications.show('Settings saved', 'success');
      await this.loadSettings();
    } catch (error) {
      handleError('Failed to save settings', error);
    }
  }
  
  async rewrite(mode = 'all', files = null) {
    const parser_mode = document.querySelector('input[name="parser_mode"]:checked')?.value || 'default';
    
    try {
      const payload = {
        mode,
        parser_mode,
        include_tags: [...State.includeSet],
        exclude_tags: [...State.excludeSet]
      };
      
      if (files) payload.files = files;
      
      const data = await api.post('/parser-rewrite', payload);
      notifications.show(`Wrote ${data.rewritten} file(s)`, 'success');
      
      if (State.selectingLogs) {
        State.selectingLogs = false;
        State.selectedLogs.clear();
        dataManager.renderLogs();
        dataManager.updateSelectionToolbar();
      }
      
      await dataManager.updateStats();
    } catch (error) {
      handleError('Rewrite failed', error);
    }
  }
}

// UI Controller (simplified)
class UIController {
  toggleSidebar() {
    const sidebar = document.querySelector('.sidebar');
    if (!sidebar) return;
    
    sidebar.classList.toggle('collapsed');
    localStorage.setItem('sidebarCollapsed', sidebar.classList.contains('collapsed') ? '1' : '0');
    
    if (DOM.toggleSidebarBtn) animate.scale(DOM.toggleSidebarBtn);
  }
  
  toggleDensity() {
    document.body.classList.toggle('compact');
    const compact = document.body.classList.contains('compact');
    
    localStorage.setItem('densityCompact', compact ? '1' : '0');
    
    if (DOM.toggleDensityBtn) {
      DOM.toggleDensityBtn.textContent = compact ? 'Normal' : 'Compact';
      animate.scale(DOM.toggleDensityBtn);
    }
  }
  
  async refreshAll() {
    if (DOM.refreshBtn) animate.spin(DOM.refreshBtn);
    
    await Promise.all([
      dataManager.updateStats(),
      dataManager.updateEndpoints()
    ]);
    
    notifications.show('Data refreshed', 'success');
  }
  
  loadPreferences() {
    if (localStorage.getItem('sidebarCollapsed') === '1') {
      document.querySelector('.sidebar')?.classList.add('collapsed');
    }
    
    if (localStorage.getItem('densityCompact') === '1') {
      document.body.classList.add('compact');
      if (DOM.toggleDensityBtn) DOM.toggleDensityBtn.textContent = 'Normal';
    }
  }
  
  startLogSelection() {
    State.selectingLogs = true;
    State.selectedLogs.clear();
    
    // Filter logs if in include mode with exclusive tags
    const mode = document.querySelector('input[name="parser_mode"]:checked')?.value || 'default';
    if (mode === 'custom' && State.includeSet.size > 0 && State.tagToFilesLower) {
      const eligible = new Set();
      const total = new Set(State.logs.map(n => n.toLowerCase()));
      
      State.includeSet.forEach(tag => {
        const files = State.tagToFilesLower[tag] || [];
        if (files.length > 0 && files.length < total.size) {
          files.forEach(f => eligible.add(f));
        }
      });
      
      if (eligible.size > 0) {
        const filtered = State.logs.filter(n => eligible.has(n.toLowerCase()));
        dataManager.renderLogsFrom(filtered);
        dataManager.updateSelectionToolbar();
        return;
      }
    }
    
    dataManager.renderLogs();
    dataManager.updateSelectionToolbar();
  }
  
  toggleSelectAll() {
    if (!State.selectingLogs) return;
    
    if (State.selectedLogs.size === State.logs.length) {
      State.selectedLogs.clear();
    } else {
      State.selectedLogs = new Set(State.logs);
    }
    
    dataManager.renderLogs();
    dataManager.updateSelectionToolbar();
  }
}

// Navigation controller
class NavigationController {
  constructor() {
    this.sections = [...document.querySelectorAll('section')];
    this.navItems = [...document.querySelectorAll('.nav-item')];
    
    this.navItems.forEach(item => {
      item.onclick = e => {
        e.preventDefault();
        const target = document.getElementById(item.getAttribute('href').slice(1));
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          this.setActive(item);
        }
      };
    });
    
    window.addEventListener('scroll', debounce(() => this.updateActive(), 50), { passive: true });
    this.updateActive();
  }
  
  updateActive() {
    const scrollY = window.scrollY + 120;
    let current = this.sections[0];
    
    for (const section of this.sections) {
      if (section.offsetTop <= scrollY) current = section;
    }
    
    const active = this.navItems.find(item => 
      item.getAttribute('href') === `#${current.id}`
    );
    
    if (active) this.setActive(active);
  }
  
  setActive(item) {
    this.navItems.forEach(navItem => {
      navItem.classList.remove('active');
      navItem.removeAttribute('aria-current');
    });
    
    item.classList.add('active');
    item.setAttribute('aria-current', 'page');
    animate.scale(item);
  }
}

// Initialize everything
let dataManager, parserController, uiController, navigationController;

async function copyText(id) {
  const el = document.getElementById(id);
  if (!el) return;
  
  const value = el.value || el.textContent || '';
  
  try {
    await navigator.clipboard.writeText(value);
    el.classList.add('copied');
    setTimeout(() => el.classList.remove('copied'), 1000);
    notifications.show('Copied to clipboard', 'success');
  } catch {
    notifications.show('Failed to copy', 'error');
  }
}

// Global functions (minimized)
const globalFunctions = {
  copyText,
  closeModal: () => new Modal().hide(),
  copyModal: async () => {
    const content = DOM.modalBody?.textContent || '';
    try {
      await navigator.clipboard.writeText(content);
      notifications.show('Copied to clipboard', 'success');
    } catch {
      notifications.show('Failed to copy', 'error');
    }
  },
  saveParserSettings: () => parserController.saveSettings(),
  rewriteParsed: () => parserController.rewrite('all'),
  openWriteOptions: () => {
    const modal = document.getElementById('writeModal');
    if (modal) {
      modal.style.display = 'flex';
      requestAnimationFrame(() => modal.classList.add('show'));
    }
  },
  closeWriteOptions: () => {
    const modal = document.getElementById('writeModal');
    if (modal) {
      modal.classList.remove('show');
      modal.style.display = 'none';
    }
  },
  writeLatest: () => {
    globalFunctions.closeWriteOptions();
    parserController.rewrite('latest');
  },
  startCustomWriteSelection: () => {
    globalFunctions.closeWriteOptions();
    uiController.startLogSelection();
  },
  toggleSelectAllLogs: () => uiController.toggleSelectAll(),
  rewriteSelectedLogs: () => {
    const files = [...State.selectedLogs];
    if (!files.length) {
      notifications.show('No files selected', 'info');
      return;
    }
    parserController.rewrite('custom', files);
  },
  cancelLogSelection: () => {
    State.selectingLogs = false;
    State.selectedLogs.clear();
    dataManager.renderLogs();
    dataManager.updateSelectionToolbar();
  },
  toggleAllTags: () => {
    if (State.includeSet.size === State.allTags.size) {
      State.excludeSet = new Set(State.allTags);
      State.includeSet.clear();
      if (DOM.toggleAllBtn) DOM.toggleAllBtn.textContent = 'Include All';
    } else {
      State.includeSet = new Set(State.allTags);
      State.excludeSet.clear();
      if (DOM.toggleAllBtn) DOM.toggleAllBtn.textContent = 'Exclude All';
    }
    parserController.renderChips();
  },
  clearAllTags: () => {
    State.includeSet.clear();
    State.excludeSet = new Set(State.allTags);
    if (DOM.toggleAllBtn) DOM.toggleAllBtn.textContent = 'Include All';
    parserController.renderChips();
    notifications.show('All tags set to Exclude', 'info');
  },
  detectTagsLatest: () => parserController.detectTags('latest'),
  detectTagsFromLogs: () => {
    const modal = document.getElementById('tagDetectModal');
    const container = document.getElementById('tagDetectList');
    if (!modal || !container) return;
    
    if (!State.logs.length) {
      container.innerHTML = '<div class="empty-state"><p>No logs available.</p></div>';
    } else {
      const fragment = document.createDocumentFragment();
      State.logs.forEach(name => {
        const label = createElement('label', { class: 'detect-item' }, [
          createElement('input', { type: 'checkbox', 'data-name': name }),
          createElement('span', { text: name })
        ]);
        fragment.appendChild(label);
      });
      container.innerHTML = '';
      container.appendChild(fragment);
    }
    
    modal.style.display = 'flex';
    requestAnimationFrame(() => modal.classList.add('show'));
  },
  closeTagDetect: () => {
    const modal = document.getElementById('tagDetectModal');
    if (modal) {
      modal.classList.remove('show');
      modal.style.display = 'none';
    }
  },
  confirmTagDetect: () => {
    const checked = [...document.querySelectorAll('#tagDetectList input:checked')]
      .map(chk => chk.dataset.name);
    
    if (!checked.length) {
      notifications.show('Select at least one log', 'info');
      return;
    }
    
    parserController.detectTags('custom', checked);
    globalFunctions.closeTagDetect();
  },
  selectAllTagDetect: () => {
    document.querySelectorAll('#tagDetectList input[type="checkbox"]')
      .forEach(chk => chk.checked = true);
  },
  clearAllTagDetect: () => {
    document.querySelectorAll('#tagDetectList input[type="checkbox"]')
      .forEach(chk => chk.checked = false);
  },
  addTagFromInput: () => {
    if (!DOM.newTagInput) return;
    const tag = DOM.newTagInput.value.trim().toLowerCase();
    if (!tag) return;
    
    if (!State.allTags.has(tag)) {
      State.allTags.add(tag);
      State.excludeSet.add(tag);
      parserController.renderChips();
      notifications.show(`Added tag: ${tag}`, 'success');
    } else {
      notifications.show('Tag already exists', 'info');
    }
    DOM.newTagInput.value = '';
  },
  refreshAll: () => uiController.refreshAll(),
  toggleVisibilityById: (id, btn) => {
    const el = document.getElementById(id);
    if (!el) return;
    const hidden = el.style.display === 'none' || getComputedStyle(el).display === 'none';
    el.style.display = hidden ? 'block' : 'none';
    if (btn) btn.setAttribute('aria-expanded', String(hidden));
  },
  toggleHelp: (id, btn) => {
    const el = document.getElementById(id);
    if (!el) return;
    const hidden = el.getAttribute('aria-hidden') !== 'false';
    el.setAttribute('aria-hidden', String(!hidden));
    el.classList.toggle('show', hidden);
    if (btn) btn.setAttribute('aria-expanded', String(hidden));
  }
};

// DOM ready
document.addEventListener('DOMContentLoaded', () => {
  document.body.classList.add('loading');
  
  initDOMCache();
  
  dataManager = new DataManager();
  parserController = new ParserController();
  uiController = new UIController();
  navigationController = new NavigationController();
  
  Object.assign(window, globalFunctions);
  
  // Setup event listeners
  document.querySelectorAll('input[name="parser_mode"]').forEach(radio => {
    radio.onchange = e => {
      const custom = e.target.value === 'custom';
      if (DOM.tagControls) {
        DOM.tagControls.style.display = custom ? 'block' : 'none';
        if (custom) animate.fadeIn(DOM.tagControls);
      }
      parserController.updateModeDisplay(e.target.value);
    };
  });
  
  if (DOM.toggleSidebarBtn) DOM.toggleSidebarBtn.onclick = () => uiController.toggleSidebar();
  if (DOM.toggleDensityBtn) DOM.toggleDensityBtn.onclick = () => uiController.toggleDensity();
  if (DOM.refreshBtn) DOM.refreshBtn.onclick = () => uiController.refreshAll();
  if (DOM.logFilter) DOM.logFilter.oninput = debounce(() => dataManager.renderLogs(), Config.DEBOUNCE_DELAY);
  if (DOM.newTagInput) DOM.newTagInput.onkeypress = e => {
    if (e.key === 'Enter') globalFunctions.addTagFromInput();
  };
  
  // Load initial data
  Promise.all([
    dataManager.updateStats(),
    dataManager.updateEndpoints(),
    parserController.loadSettings()
  ]).then(() => {
    document.body.classList.remove('loading');
  });
  
  uiController.loadPreferences();
  
  // Auto refresh
  State.refreshTimer = setInterval(() => {
    dataManager.updateStats(true);
    dataManager.updateEndpoints(true);
  }, Config.REFRESH_INTERVAL);
});

// Cleanup
window.addEventListener('beforeunload', () => {
  if (State.refreshTimer) clearInterval(State.refreshTimer);
});

// CSS animations and utility classes are defined in app/static/css/app.css
