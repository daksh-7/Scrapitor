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
  title="Click to toggle: Include ↔ Exclude"
  {onclick}
  {onmouseenter}
  {onmouseleave}
>
  {displayName}
</button>

<style>
  .tag-chip {
    padding: var(--space-xs) var(--space-md);
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    font-size: 0.875rem;
    font-weight: 500;
    background: rgba(255, 255, 255, 0.02);
    cursor: pointer;
    color: var(--text-secondary);
    transition: background-color 0.15s, border-color 0.15s, color 0.15s;
  }

  .tag-chip:hover {
    border-color: var(--border-interactive);
  }

  .tag-chip.include {
    border-color: var(--accent-primary);
    background: rgba(0, 212, 255, 0.1);
    color: var(--accent-primary);
  }

  .tag-chip.exclude {
    border-color: var(--accent-danger);
    background: rgba(255, 51, 102, 0.1);
    color: var(--accent-danger);
  }
</style>
