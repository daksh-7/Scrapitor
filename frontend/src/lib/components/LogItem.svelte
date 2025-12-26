<script lang="ts">
  import { logsStore } from '$lib/stores';
  import Icon from './Icon.svelte';

  interface Props {
    name: string;
    selectable?: boolean;
    selected?: boolean;
    onclick: () => void;
    onOpenParsed?: () => void;
    onRename?: () => void;
  }

  let { name, selectable = false, selected = false, onclick, onOpenParsed, onRename }: Props = $props();

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
</script>

<div 
  class="log-item"
  class:selectable
  class:selected
  data-name={name}
  {onclick}
  role="button"
  tabindex="0"
  onkeydown={(e) => e.key === 'Enter' && onclick()}
>
  <div class="log-main">
    {#if selectable}
      <div class="checkbox" class:checked={selected}>
        {#if selected}
          <Icon name="check" size={12} />
        {/if}
      </div>
    {/if}
    <span class="log-filename">{name}</span>
  </div>
  
  <div class="log-actions">
    {#if onOpenParsed && !selectable}
      <button 
        class="action-chip" 
        onclick={(e) => { e.stopPropagation(); onOpenParsed?.(); }}
        title="View parsed TXT versions"
      >
        TXT
      </button>
    {/if}
    {#if onRename && !selectable}
      <button 
        class="action-btn" 
        onclick={(e) => { e.stopPropagation(); onRename?.(); }}
        title="Rename"
      >
        <Icon name="edit" size={12} />
      </button>
    {/if}
    <span class="log-time">{formatTime(meta?.mtime)}</span>
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
  }

  .log-item:hover .action-btn {
    opacity: 1;
  }

  .action-btn:hover {
    color: var(--text-primary);
    background: var(--bg-active);
  }
</style>
