<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    id: string;
    title?: string;
    children: Snippet;
  }

  let { id, title, children }: Props = $props();
</script>

<section {id} class="section fade-in-up" aria-labelledby={title ? `${id}-title` : undefined}>
  {#if title}
    <h2 id="{id}-title" class="section-header">{title}</h2>
  {/if}
  <div class="section-content">
    {@render children()}
  </div>
</section>

<style>
  .section {
    background: var(--bg-surface);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-xl);
    margin-bottom: var(--space-xl);
    overflow: hidden;
  }

  .section-header {
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-muted);
    padding: var(--space-md) var(--space-xl);
    border-bottom: 1px solid var(--border-subtle);
    background: var(--bg-elevated);
  }

  .section-content {
    padding: var(--space-xl);
  }

  @media (max-width: 640px) {
    .section-content {
      padding: var(--space-lg);
    }
  }
</style>
