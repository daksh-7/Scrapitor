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

  // Memoize the lowercase search term (no debounce needed with derived)
  const filterLower = $derived(filterText.toLowerCase());

  const filteredLogs = $derived(
    filterText
      ? logsStore.logs.filter(name => name.toLowerCase().includes(filterLower))
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
      {#each visibleLogs as name (name)}
        <LogItem 
          {name}
          selectable={logsStore.selectingLogs}
          selected={logsStore.selectedLogs.has(name)}
          onclick={() => logsStore.selectingLogs ? logsStore.toggleSelection(name) : openLog(name)}
          onOpenParsed={() => openParsedList(name)}
        />
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
<Modal
  open={parsedModalOpen}
  title={parsedModalTitle}
  onClose={() => parsedModalOpen = false}
>
  {#snippet children()}
    <div class="version-picker">
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
  {/snippet}
</Modal>

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
  .logs-container {
    background: var(--surface-secondary);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-lg);
    padding: var(--space-md);
    height: min(60vh, 600px);
    overflow-y: auto;
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
  }

  /* Version picker styles (used inside Modal) */
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
    transition: border-color 0.15s;
  }

  .version-item:hover {
    border-color: var(--border-interactive);
  }

  .version-list .meta {
    color: var(--text-tertiary);
    font-size: 0.75rem;
  }
</style>
