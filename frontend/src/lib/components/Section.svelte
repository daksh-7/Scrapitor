<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    id: string;
    title: string;
    children: Snippet;
  }

  let { id, title, children }: Props = $props();
</script>

<section {id} class="section" aria-labelledby="{id}-title">
  <h2 id="{id}-title" class="section-header">{title}</h2>
  {@render children()}
</section>

<style>
  .section {
    background: var(--surface-primary);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-xl);
    padding: var(--space-xl);
    margin-bottom: var(--space-lg);
    position: relative;
  }

  .section-header {
    font-size: 1.5rem;
    font-weight: 700;
    margin-bottom: var(--space-xl);
    background: linear-gradient(135deg, 
      var(--accent-primary) 0%, 
      var(--accent-secondary) 100%);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    display: flex;
    align-items: center;
    gap: var(--space-md);
    letter-spacing: -0.03em;
  }

</style>
