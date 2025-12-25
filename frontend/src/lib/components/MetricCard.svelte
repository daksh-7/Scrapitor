<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    title: string;
    value: number | string;
    label: string;
    icon?: Snippet;
  }

  let { title, value, label, icon }: Props = $props();

  function formatNumber(n: number | string): string {
    if (typeof n === 'string') return n;
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }
</script>

<div class="metric-card" aria-live="polite">
  <div class="metric-header">
    <div>
      <div class="metric-title">{title}</div>
      <div class="metric-value">{formatNumber(value)}</div>
      <div class="metric-label">{label}</div>
    </div>
    {#if icon}
      <div class="metric-icon" aria-hidden="true">
        {@render icon()}
      </div>
    {/if}
  </div>
</div>

<style>
  .metric-card {
    background: var(--surface-primary);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-subtle);
    padding: var(--space-lg);
    transition: border-color 0.15s;
  }

  .metric-card:hover {
    border-color: var(--border-default);
  }

  .metric-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: var(--space-md);
  }

  .metric-title {
    font-size: 0.8125rem;
    color: var(--text-tertiary);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: var(--space-xs);
  }

  .metric-value {
    font-size: 2.25rem;
    font-weight: 800;
    background: linear-gradient(135deg, var(--text-primary) 0%, var(--accent-primary) 100%);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    letter-spacing: -0.03em;
    line-height: 1;
    margin: var(--space-xs) 0;
  }

  .metric-label {
    font-size: 0.875rem;
    color: var(--text-tertiary);
    font-weight: 500;
  }

  .metric-icon {
    width: 48px;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius-md);
    background: rgba(0, 212, 255, 0.08);
    color: var(--accent-primary);
  }

  .metric-icon :global(svg) {
    width: 24px;
    height: 24px;
  }

</style>
