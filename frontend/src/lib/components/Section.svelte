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

  /* Mobile breakpoint */
  @media (max-width: 767px) {
    .section {
      border-radius: var(--radius-lg);
      margin-bottom: var(--space-lg);
    }

    .section-header {
      padding: var(--space-sm) var(--space-md);
      font-size: 0.75rem;
    }

    .section-content {
      padding: var(--space-md);
    }
  }

  /* Small mobile breakpoint */
  @media (max-width: 479px) {
    .section {
      border-radius: var(--radius-md);
      margin-bottom: var(--space-md);
    }

    .section-header {
      padding: var(--space-sm);
      font-size: 0.6875rem;
    }

    .section-content {
      padding: var(--space-sm);
    }
  }
</style>
