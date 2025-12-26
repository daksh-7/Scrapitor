<script lang="ts">
  interface Props {
    tag: string;
    state: 'include' | 'exclude' | 'neutral';
    onclick: () => void;
    onmouseenter?: () => void;
    onmouseleave?: () => void;
  }

  let { tag, state, onclick, onmouseenter, onmouseleave }: Props = $props();

  const displayName = $derived(
    tag.toLowerCase() === 'untagged content' ? 'Untagged Content' : tag
  );
</script>

<button
  class="tag-chip"
  class:include={state === 'include'}
  class:exclude={state === 'exclude'}
  title="Click to toggle: Include → Exclude → Neutral"
  {onclick}
  {onmouseenter}
  {onmouseleave}
>
  <span class="tag-indicator"></span>
  <span class="tag-name">{displayName}</span>
</button>

<style>
  .tag-chip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 5px 12px;
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    font-size: 0.8125rem;
    font-weight: 500;
    background: var(--bg-elevated);
    cursor: pointer;
    color: var(--text-secondary);
    transition: 
      background-color var(--duration-fast) var(--ease-out),
      border-color var(--duration-fast) var(--ease-out),
      color var(--duration-fast) var(--ease-out);
  }

  .tag-chip:hover {
    border-color: var(--border-strong);
    background: var(--bg-hover);
  }

  .tag-indicator {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--text-faint);
    transition: background-color var(--duration-fast);
  }

  .tag-chip.include {
    border-color: var(--accent-border);
    background: var(--accent-subtle);
    color: var(--accent);
  }

  .tag-chip.include .tag-indicator {
    background: var(--accent);
  }

  .tag-chip.exclude {
    border-color: var(--danger-border);
    background: var(--danger-subtle);
    color: var(--danger);
  }

  .tag-chip.exclude .tag-indicator {
    background: var(--danger);
  }

  .tag-name {
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
