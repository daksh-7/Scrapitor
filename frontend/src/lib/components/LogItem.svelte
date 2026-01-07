<script lang="ts">
  import { logsStore, uiStore } from '$lib/stores';
  import Icon from './Icon.svelte';

  interface Props {
    name: string;
    selectable?: boolean;
    selected?: boolean;
    onclick: () => void;
    onOpenParsed?: () => void;
  }

  let { name, selectable = false, selected = false, onclick, onOpenParsed }: Props = $props();

  // Inline rename state
  let isRenaming = $state(false);
  let renameValue = $state('');
  let inputRef = $state<HTMLInputElement | null>(null);

  const meta = $derived(logsStore.getMeta(name));

  function formatTime(mtime: number | undefined): string {
    if (!mtime || Number.isNaN(mtime)) return '';
    try {
      const d = new Date(mtime * 1000);
      const now = new Date();
      const pad = (n: number) => String(n).padStart(2, '0');
      const hhmm = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
      if (d.toDateString() === now.toDateString()) return hhmm;
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${hhmm}`;
    } catch {
      return '';
    }
  }

  function startRename(e: Event) {
    e.stopPropagation();
    renameValue = name.replace(/\.json$/, '');
    isRenaming = true;
    setTimeout(() => {
      inputRef?.focus();
      inputRef?.select();
    }, 0);
  }

  async function commitRename() {
    const newBasename = renameValue.trim();
    if (!newBasename || newBasename === name.replace(/\.json$/, '')) {
      cancelRename();
      return;
    }
    
    const newName = newBasename + '.json';
    try {
      await logsStore.rename(name, newName);
      uiStore.notify(`Renamed to ${newName}`);
    } catch (e) {
      uiStore.notify(e instanceof Error ? e.message : 'Rename failed', 'error');
    }
    isRenaming = false;
  }

  function cancelRename() {
    isRenaming = false;
    renameValue = '';
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      e.preventDefault();
      commitRename();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      cancelRename();
    }
  }

  function handleBlur() {
    setTimeout(() => {
      if (isRenaming) {
        commitRename();
      }
    }, 100);
  }
</script>

<div 
  class="log-item"
  class:selectable
  class:selected
  class:renaming={isRenaming}
  data-name={name}
  onclick={() => !isRenaming && onclick()}
  role="button"
  tabindex="0"
  onkeydown={(e) => !isRenaming && e.key === 'Enter' && onclick()}
>
  <div class="log-main">
    {#if selectable}
      <div class="checkbox" class:checked={selected}>
        {#if selected}
          <Icon name="check" size={12} />
        {/if}
      </div>
    {/if}
    
    {#if isRenaming}
      <div class="rename-input-wrapper">
        <input 
          type="text"
          class="rename-input"
          bind:this={inputRef}
          bind:value={renameValue}
          onkeydown={handleKeydown}
          onblur={handleBlur}
          onclick={(e) => e.stopPropagation()}
        />
        <span class="rename-ext">.json</span>
      </div>
    {:else}
      <span class="log-filename">{name}</span>
    {/if}
  </div>
  
  <div class="log-actions">
    {#if isRenaming}
      <button 
        class="action-btn action-btn--visible" 
        onclick={(e) => { e.stopPropagation(); commitRename(); }}
        title="Save"
      >
        <Icon name="check" size={12} />
      </button>
      <button 
        class="action-btn action-btn--visible" 
        onclick={(e) => { e.stopPropagation(); cancelRename(); }}
        title="Cancel"
      >
        <Icon name="close" size={12} />
      </button>
    {:else}
      {#if onOpenParsed && !selectable}
        <button 
          class="action-chip" 
          onclick={(e) => { e.stopPropagation(); onOpenParsed?.(); }}
          title="View parsed TXT versions"
        >
          TXT
        </button>
      {/if}
      {#if !selectable}
        <button 
          class="action-btn" 
          onclick={startRename}
          title="Rename"
        >
          <Icon name="edit" size={12} />
        </button>
      {/if}
      <span class="log-time">{formatTime(meta?.mtime)}</span>
    {/if}
  </div>
</div>

<style>
  .log-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--space-sm) var(--space-md);
    margin-bottom: 2px;
    border-radius: var(--radius-md);
    background: transparent;
    border: 1px solid transparent;
    cursor: pointer;
    transition:
      background-color var(--duration-fast) var(--ease-out),
      border-color var(--duration-fast) var(--ease-out);
    gap: var(--space-md);
    -webkit-tap-highlight-color: transparent;
  }

  .log-item:hover {
    background: var(--bg-hover);
  }

  .log-item.selectable {
    cursor: pointer;
  }

  .log-item.selected {
    background: var(--accent-subtle);
    border-color: var(--accent-border);
  }

  .log-item.renaming {
    background: var(--bg-hover);
    border-color: var(--accent-border);
  }

  .log-main {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    min-width: 0;
    flex: 1;
  }

  .checkbox {
    width: 16px;
    height: 16px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: var(--bg-surface);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition:
      background-color var(--duration-fast),
      border-color var(--duration-fast);
  }

  .checkbox.checked {
    background: var(--accent);
    border-color: var(--accent);
    color: var(--bg-base);
  }

  .log-filename {
    font-weight: 500;
    color: var(--text-primary);
    font-family: 'Geist Mono', monospace;
    font-size: 0.8125rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Inline rename input */
  .rename-input-wrapper {
    display: flex;
    align-items: center;
    flex: 1;
    min-width: 0;
  }

  .rename-input {
    flex: 1;
    min-width: 0;
    padding: 2px 6px;
    border: 1px solid var(--accent);
    border-radius: var(--radius-sm);
    background: var(--bg-surface);
    color: var(--text-primary);
    font-family: 'Geist Mono', monospace;
    font-size: 0.8125rem;
    font-weight: 500;
    outline: none;
  }

  .rename-input:focus {
    box-shadow: 0 0 0 2px var(--accent-subtle);
  }

  .rename-ext {
    font-family: 'Geist Mono', monospace;
    font-size: 0.8125rem;
    color: var(--text-muted);
    margin-left: 2px;
    flex-shrink: 0;
  }

  .log-actions {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    flex-shrink: 0;
  }

  .log-time {
    font-size: 0.75rem;
    color: var(--text-faint);
    font-family: 'Geist Mono', monospace;
    font-variant-numeric: tabular-nums;
  }

  .action-chip {
    padding: 3px 8px;
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    border-radius: var(--radius-sm);
    border: 1px solid var(--accent-border);
    background: var(--accent-subtle);
    color: var(--accent);
    cursor: pointer;
    opacity: 0;
    transition:
      opacity var(--duration-fast),
      background-color var(--duration-fast);
    -webkit-tap-highlight-color: transparent;
  }

  .log-item:hover .action-chip {
    opacity: 1;
  }

  .action-chip:hover {
    background: var(--accent);
    color: var(--bg-base);
  }

  .action-btn {
    width: 22px;
    height: 22px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--text-muted);
    border-radius: var(--radius-sm);
    cursor: pointer;
    opacity: 0;
    transition:
      opacity var(--duration-fast),
      color var(--duration-fast),
      background-color var(--duration-fast);
    -webkit-tap-highlight-color: transparent;
  }

  .log-item:hover .action-btn {
    opacity: 1;
  }

  .action-btn--visible {
    opacity: 1;
  }

  .action-btn:hover {
    color: var(--text-primary);
    background: var(--bg-active);
  }

  /* Mobile breakpoint */
  @media (max-width: 767px) {
    .log-item {
      padding: var(--space-md);
      min-height: 56px;
      gap: var(--space-md);
      border-radius: var(--radius-lg);
      margin-bottom: var(--space-xs);
    }

    .log-item:active {
      transform: scale(0.98);
      background: var(--bg-active);
    }

    .log-main {
      gap: var(--space-md);
    }

    .checkbox {
      width: 22px;
      height: 22px;
      border-radius: var(--radius-md);
    }

    .log-filename {
      font-size: 0.8125rem;
      font-weight: 500;
    }

    .log-actions {
      gap: var(--space-md);
    }

    .log-time {
      font-size: 0.6875rem;
      display: none; /* Hide on mobile to save space */
    }

    /* Always show action chip on mobile for touch */
    .action-chip {
      opacity: 1;
      padding: 8px 14px;
      font-size: 0.6875rem;
      min-height: 36px;
      display: flex;
      align-items: center;
      border-radius: var(--radius-md);
    }

    .action-chip:active {
      transform: scale(0.95);
    }

    .action-btn {
      width: 36px;
      height: 36px;
      opacity: 1;
      border-radius: var(--radius-md);
      background: var(--bg-hover);
    }

    .action-btn:active {
      background: var(--bg-active);
    }

    .rename-input {
      font-size: 16px; /* Prevent iOS zoom */
      padding: 8px 12px;
      border-radius: var(--radius-md);
      min-height: 40px;
    }

    .rename-ext {
      font-size: 0.875rem;
    }
  }

  /* Small mobile breakpoint */
  @media (max-width: 479px) {
    .log-item {
      padding: var(--space-sm) var(--space-md);
      min-height: 52px;
    }

    .log-filename {
      font-size: 0.75rem;
    }

    .action-chip {
      padding: 6px 10px;
      font-size: 0.625rem;
      min-height: 32px;
    }

    .action-btn {
      width: 32px;
      height: 32px;
    }

    .checkbox {
      width: 20px;
      height: 20px;
    }
  }
</style>
