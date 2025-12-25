<script lang="ts">
  import { logsStore } from '$lib/stores';

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
  class:active={selected}
  data-name={name}
  {onclick}
  role="button"
  tabindex="0"
  onkeydown={(e) => e.key === 'Enter' && onclick()}
>
  <div class="log-left">
    <span class="log-filename">{name}</span>
    {#if onOpenParsed && !selectable}
      <button 
        class="mini-btn mini-txt-btn loud" 
        onclick={(e) => { e.stopPropagation(); onOpenParsed?.(); }}
      >
        TXT
      </button>
    {/if}
    {#if onRename && !selectable}
      <button 
        class="icon-btn mini-rename-btn" 
        onclick={(e) => { e.stopPropagation(); onRename?.(); }}
      >
        ✎
      </button>
    {/if}
  </div>
  <span class="log-time">{formatTime(meta?.mtime)}</span>
</div>

<style>
  .log-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--space-md);
    margin-bottom: var(--space-sm);
    border-radius: var(--radius-md);
    background: rgba(255, 255, 255, 0.01);
    border: 1px solid var(--border-subtle);
    cursor: pointer;
    transition: background-color 0.15s, border-color 0.15s;
  }

  .log-item:hover {
    background: rgba(255, 255, 255, 0.03);
    border-color: var(--border-interactive);
  }

  .log-item.selectable {
    cursor: pointer;
  }

  .log-item.selectable.active {
    border-color: var(--accent-primary);
    background: rgba(0, 212, 255, 0.08);
  }

  .log-left {
    display: inline-flex;
    align-items: center;
    gap: 12px;
  }

  .log-filename {
    font-weight: 500;
    color: var(--text-primary);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.875rem;
  }

  .log-time {
    font-size: 0.75rem;
    color: var(--text-muted);
  }

  .mini-btn {
    padding: 4px 8px;
    font-size: 0.75rem;
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-primary);
    cursor: pointer;
    transition: border-color 0.15s;
  }

  .mini-btn:hover {
    border-color: var(--border-interactive);
  }

  .mini-txt-btn {
    opacity: 0;
    transition: opacity 0.15s;
  }

  .log-item:hover .mini-txt-btn {
    opacity: 1;
  }

  .mini-btn.loud {
    background: linear-gradient(135deg, var(--accent-secondary) 0%, var(--accent-secondary) 100%);
    color: #000;
    border-color: rgba(0, 255, 136, 0.6);
  }

  .mini-btn.loud:hover {
    filter: brightness(1.1);
  }

  .icon-btn {
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-primary);
    border-radius: var(--radius-full);
    padding: 4px 8px;
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.15s, border-color 0.15s;
  }

  .log-item:hover .icon-btn {
    opacity: 1;
  }

  .icon-btn:hover {
    border-color: var(--border-interactive);
  }
</style>
