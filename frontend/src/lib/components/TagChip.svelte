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
    transition: transform 0.2s var(--ease-bounce), box-shadow 0.2s var(--ease-bounce), color 0.2s var(--ease-bounce), background-color 0.2s var(--ease-bounce), border-color 0.2s var(--ease-bounce);
    position: relative;
    overflow: hidden;
    color: var(--text-secondary);
  }

  .tag-chip::before {
    content: '';
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at center, 
      rgba(255, 255, 255, 0.1) 0%, 
      transparent 70%);
    opacity: 0;
    transition: opacity 0.3s;
  }

  .tag-chip:hover {
    transform: translateY(-2px) scale(1.05);
  }

  .tag-chip:hover::before {
    opacity: 1;
  }

  .tag-chip.include {
    border-color: var(--accent-primary);
    background: rgba(0, 212, 255, 0.1);
    color: var(--accent-primary);
    box-shadow: 
      0 0 0 2px rgba(0, 212, 255, 0.1),
      0 0 20px rgba(0, 212, 255, 0.15);
  }

  .tag-chip.exclude {
    border-color: var(--accent-danger);
    background: rgba(255, 51, 102, 0.1);
    color: var(--accent-danger);
    box-shadow: 
      0 0 0 2px rgba(255, 51, 102, 0.1),
      0 0 20px rgba(255, 51, 102, 0.15);
  }
</style>

