<script lang="ts">
  import Section from '$lib/components/Section.svelte';
  import LogItem from '$lib/components/LogItem.svelte';
  import Modal from '$lib/components/Modal.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import { logsStore, parserStore, uiStore } from '$lib/stores';

  let filterText = $state('');
  let logModalOpen = $state(false);
  let logModalTitle = $state('');
  let logModalContent = $state('');
  let parsedModalOpen = $state(false);
  let parsedModalTitle = $state('');
  let parsedVersions = $state<Array<{file: string; mtime: number; size: number}>>([]);
  let parsedModalLogName = $state('');
  let confirmOpen = $state(false);
  let confirmMessage = $state('');
  let confirmAction = $state<() => void>(() => {});

  const filteredLogs = $derived(
    filterText
      ? logsStore.logs.filter(name => name.toLowerCase().includes(filterText.toLowerCase()))
      : logsStore.logs
  );

  const visibleLogs = $derived(filteredLogs.slice(0, 100));

  async function openLog(name: string) {
    logModalTitle = name;
    logModalContent = 'Loading…';
    logModalOpen = true;

    try {
      const content = await logsStore.getContent(name);
      logModalContent = content;
    } catch (e) {
      logModalContent = `Error: ${e instanceof Error ? e.message : 'Failed to load'}`;
    }
  }

  async function openParsedList(name: string) {
    parsedModalLogName = name;
    parsedModalTitle = `${name} — TXT`;
    parsedVersions = [];
    parsedModalOpen = true;

    try {
      const data = await logsStore.getParsedVersions(name);
      parsedVersions = data.versions;
      if (!parsedVersions.length) {
        uiStore.notify('No parsed TXT versions yet', 'info');
        parsedModalOpen = false;
      }
    } catch {
      parsedModalOpen = false;
    }
  }

  async function openParsedContent(logName: string, fileName: string) {
    logModalTitle = `${logName} — ${fileName}`;
    logModalContent = 'Loading…';
    logModalOpen = true;

    try {
      const content = await logsStore.getParsedText(logName, fileName);
      logModalContent = content;
    } catch (e) {
      logModalContent = `Error: ${e instanceof Error ? e.message : 'Failed to load'}`;
    }
  }

  function startDeleteSelection() {
    logsStore.startSelection('delete');
  }

  function cancelSelection() {
    logsStore.cancelSelection();
  }

  async function deleteSelected() {
    const count = logsStore.selectedCount;
    if (count === 0) {
      uiStore.notify('No files selected', 'info');
      return;
    }
    confirmMessage = `Delete ${count} log${count === 1 ? '' : 's'}? This cannot be undone.`;
    confirmAction = async () => {
      const deleted = await logsStore.deleteSelected();
      uiStore.notify(`Deleted ${deleted} log${deleted === 1 ? '' : 's'}`);
    };
    confirmOpen = true;
  }

  async function rewriteSelected() {
    const files = [...logsStore.selectedLogs];
    if (files.length === 0) {
      uiStore.notify('No files selected', 'info');
      return;
    }
    try {
      const result = await parserStore.rewrite('custom', files);
      uiStore.notify(`Wrote ${result.rewritten} file(s)`);
      logsStore.cancelSelection();
      await logsStore.refresh();
    } catch {
      // Error handled by store
    }
  }

  function formatDate(mtime: number): string {
    if (!mtime) return '';
    return new Date(mtime * 1000).toISOString().slice(0, 19).replace('T', ' ');
  }

  function formatSize(size: number): string {
    return `${Math.max(1, Math.round(size / 1024))} KB`;
  }
</script>

<Section id="activity" title="Activity">
  <div class="input-group" style="margin-bottom: 0.8rem;">
    <input 
      class="copy-input" 
      placeholder="Filter logs by name…" 
      aria-label="Filter logs by name"
      bind:value={filterText}
    />
    <button class="button button-secondary" onclick={() => logsStore.refresh()}>Refresh</button>
  </div>

  <div class="action-bar" style="margin-bottom: 0.4rem; justify-content: flex-end;">
    {#if !logsStore.selectingLogs}
      <button class="toolbar-btn toolbar-btn--danger" onclick={startDeleteSelection}>
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 6h18" stroke-linecap="round"/>
          <path d="M10 11v6M14 11v6"/>
        </svg>
        <span class="btn-label">Delete…</span>
      </button>
    {/if}
  </div>

  {#if logsStore.selectingLogs}
    <div class="action-bar" style="margin-bottom: 0.8rem;">
      <button class="toolbar-btn" onclick={() => logsStore.toggleSelectAll()}>
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M9 12l2 2 4-4" stroke-linecap="round" stroke-linejoin="round"/>
          <rect x="3" y="3" width="18" height="18" rx="4"/>
        </svg>
        <span class="btn-label">
          {visibleLogs.every(n => logsStore.selectedLogs.has(n)) ? 'Deselect All' : 'Select All'}
        </span>
      </button>
      {#if logsStore.selectionAction === 'write'}
        <button class="toolbar-btn toolbar-btn--accent" onclick={rewriteSelected}>
          <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M4 17l6 3 10-6-6-3-10 6z"/>
          </svg>
          <span class="btn-label">Write Selected</span>
        </button>
      {:else}
        <button class="toolbar-btn toolbar-btn--danger" onclick={deleteSelected}>
          <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 6h18" stroke-linecap="round"/>
            <path d="M10 11v6M14 11v6"/>
          </svg>
          <span class="btn-label">Delete Selected</span>
        </button>
      {/if}
      <button class="toolbar-btn" onclick={cancelSelection}>
        <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M6 6l12 12M18 6L6 18" stroke-linecap="round"/>
        </svg>
        <span class="btn-label">Cancel</span>
      </button>
    </div>
  {/if}

  <div class="logs-container">
    {#if visibleLogs.length === 0}
      <div class="empty-state">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/>
          <path d="M12 6v6l4 2"/>
        </svg>
        <p>Waiting for requests...</p>
      </div>
    {:else}
      {#each visibleLogs as name, i (name)}
        <div style="animation-delay: {i * 20}ms" class="fade-in-up">
          <LogItem 
            {name}
            selectable={logsStore.selectingLogs}
            selected={logsStore.selectedLogs.has(name)}
            onclick={() => logsStore.selectingLogs ? logsStore.toggleSelection(name) : openLog(name)}
            onOpenParsed={() => openParsedList(name)}
          />
        </div>
      {/each}
    {/if}
  </div>
</Section>

<!-- Log Content Modal -->
<Modal 
  open={logModalOpen} 
  title={logModalTitle} 
  onClose={() => logModalOpen = false}
  onBack={parsedModalOpen ? () => { logModalOpen = false; openParsedList(parsedModalLogName); } : undefined}
>
  {#snippet children()}
    {logModalContent}
  {/snippet}
</Modal>

<!-- Parsed Versions Modal -->
{#if parsedModalOpen}
  <div class="modal" role="dialog" aria-modal="true">
    <div class="modal-backdrop" onclick={() => parsedModalOpen = false}></div>
    <div class="modal-panel">
      <div class="modal-header">
        <div class="modal-title">{parsedModalTitle}</div>
        <div class="modal-actions action-bar">
          <button class="toolbar-btn" onclick={() => parsedModalOpen = false}>
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M6 6l12 12M18 6L6 18" stroke-linecap="round"/>
            </svg>
            <span class="btn-label">Close</span>
          </button>
        </div>
      </div>
      <div class="modal-body version-picker">
        <div class="version-header">Parsed TXT Versions</div>
        <ul class="version-list">
          {#each parsedVersions as version}
            <li>
              <button 
                class="version-item" 
                onclick={() => { parsedModalOpen = false; openParsedContent(parsedModalLogName, version.file); }}
              >
                {version.file}
              </button>
              <span class="meta">{formatDate(version.mtime)} • {formatSize(version.size)}</span>
            </li>
          {/each}
        </ul>
      </div>
    </div>
  </div>
{/if}

<!-- Confirm Modal -->
<ConfirmModal 
  open={confirmOpen}
  title="Delete Logs"
  message={confirmMessage}
  confirmText="Delete"
  cancelText="Cancel"
  danger={true}
  onConfirm={() => { confirmOpen = false; confirmAction(); }}
  onCancel={() => confirmOpen = false}
/>

<style>
  .input-group {
    display: flex;
    gap: var(--space-sm);
  }

  .copy-input {
    flex: 1;
    padding: var(--space-sm) var(--space-md);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-primary);
    font-size: 0.9375rem;
  }

  .button {
    background: linear-gradient(135deg, var(--accent-primary) 0%, var(--accent-secondary) 100%);
    color: var(--bg-primary);
    border: none;
    padding: var(--space-sm) var(--space-lg);
    border-radius: var(--radius-md);
    font-weight: 600;
    cursor: pointer;
  }

  .button-secondary {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid var(--border-default);
    color: var(--text-primary);
  }

  .action-bar {
    display: flex;
    gap: var(--space-sm);
    align-items: center;
    flex-wrap: wrap;
  }

  .toolbar-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    padding: 0.4rem 0.75rem;
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s var(--ease-smooth);
  }

  .toolbar-btn:hover {
    border-color: var(--border-interactive);
    background: rgba(255, 255, 255, 0.04);
    color: var(--text-primary);
  }

  .toolbar-btn--accent {
    border-color: var(--border-interactive);
    color: var(--accent-primary);
  }

  .toolbar-btn--danger {
    color: var(--accent-danger);
    border-color: rgba(255, 51, 102, 0.35);
  }

  .btn-icon {
    width: 16px;
    height: 16px;
  }

  .logs-container {
    background: linear-gradient(135deg, rgba(22, 24, 28, 0.8) 0%, rgba(16, 18, 21, 0.9) 100%);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-lg);
    padding: var(--space-md);
    height: min(60vh, 600px);
    overflow-y: auto;
    box-shadow: inset 0 2px 8px rgba(0, 0, 0, 0.2), var(--shadow-float);
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: var(--space-3xl) var(--space-xl);
    color: var(--text-muted);
    text-align: center;
  }

  .empty-state svg {
    width: 64px;
    height: 64px;
    margin-bottom: var(--space-lg);
    opacity: 0.3;
    animation: float 3s ease-in-out infinite;
  }

  @keyframes float {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-10px); }
  }

  /* Modal styles */
  .modal {
    position: fixed;
    inset: 0;
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-lg);
    animation: fadeIn 0.12s var(--ease-smooth);
  }

  .modal-backdrop {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.8);
    backdrop-filter: blur(4px);
  }

  .modal-panel {
    position: relative;
    width: min(700px, 90vw);
    max-height: 85vh;
    background: linear-gradient(135deg, rgba(26, 29, 33, 0.95) 0%, rgba(18, 20, 23, 0.98) 100%);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-xl);
    box-shadow: var(--shadow-2xl);
    display: flex;
    flex-direction: column;
    animation: slideUp 0.15s var(--ease-expo);
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-lg);
    border-bottom: 1px solid var(--border-subtle);
  }

  .modal-title {
    font-weight: 700;
    font-size: 1.125rem;
    color: var(--text-primary);
    font-family: 'JetBrains Mono', monospace;
  }

  .modal-actions {
    display: flex;
    gap: var(--space-sm);
  }

  .modal-body {
    padding: var(--space-lg);
    overflow-y: auto;
  }

  .version-picker {
    white-space: normal;
    word-break: normal;
  }

  .version-header {
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: var(--space-md);
  }

  .version-list {
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .version-list li {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
  }

  .version-item {
    padding: 6px 10px;
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-primary);
    cursor: pointer;
    transition: all 0.2s var(--ease-smooth);
  }

  .version-item:hover {
    border-color: var(--border-interactive);
  }

  .version-list .meta {
    color: var(--text-tertiary);
    font-size: 0.75rem;
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes slideUp {
    from { transform: translateY(40px) scale(0.95); opacity: 0; }
    to { transform: translateY(0) scale(1); opacity: 1; }
  }
</style>

