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
    return n.toLocaleString();
  }
</script>

<article class="metric-card" aria-live="polite">
  <div class="metric-content">
    <header class="metric-header">
      <span class="metric-title">{title}</span>
    </header>
    <div class="metric-value">{formatNumber(value)}</div>
    <p class="metric-label">{label}</p>
  </div>
  {#if icon}
    <div class="metric-icon" aria-hidden="true">
      {@render icon()}
    </div>
  {/if}
</article>

<style>
  .metric-card {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-lg);
    background: var(--bg-elevated);
    border-radius: var(--radius-xl);
    border: 1px solid var(--border-subtle);
    padding: var(--space-xl) var(--space-2xl);
    min-height: 140px;
    transition:
      border-color var(--duration-fast) var(--ease-out),
      transform var(--duration-fast) var(--ease-out);
  }

  .metric-card:hover {
    border-color: var(--border-default);
  }

  .metric-content {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    justify-content: center;
  }

  .metric-header {
    margin-bottom: var(--space-sm);
  }

  .metric-title {
    font-size: 0.8125rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-muted);
  }

  .metric-value {
    font-size: 3rem;
    font-weight: 700;
    color: var(--text-primary);
    letter-spacing: -0.03em;
    line-height: 1;
    margin: var(--space-sm) 0;
    font-variant-numeric: tabular-nums;
  }

  .metric-label {
    font-size: 0.875rem;
    color: var(--text-muted);
    font-weight: 400;
  }

  .metric-icon {
    width: 56px;
    height: 56px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius-lg);
    background: var(--accent-subtle);
    color: var(--accent);
    flex-shrink: 0;
  }

  .metric-icon :global(svg) {
    width: 26px;
    height: 26px;
  }

  /* Tablet breakpoint */
  @media (max-width: 1023px) {
    .metric-card {
      padding: var(--space-lg) var(--space-xl);
      min-height: 130px;
    }

    .metric-value {
      font-size: 2.5rem;
    }
  }

  /* Mobile breakpoint */
  @media (max-width: 767px) {
    .metric-card {
      padding: var(--space-md) var(--space-lg);
      min-height: 110px;
      gap: var(--space-md);
      border-radius: var(--radius-lg);
    }

    .metric-title {
      font-size: 0.6875rem;
      letter-spacing: 0.08em;
    }

    .metric-value {
      font-size: 2rem;
      margin: var(--space-xs) 0;
    }

    .metric-label {
      font-size: 0.75rem;
    }

    .metric-icon {
      width: 44px;
      height: 44px;
      border-radius: var(--radius-md);
    }

    .metric-icon :global(svg) {
      width: 20px;
      height: 20px;
    }
  }

  /* Small mobile breakpoint */
  @media (max-width: 479px) {
    .metric-card {
      padding: var(--space-sm) var(--space-md);
      min-height: 90px;
      gap: var(--space-sm);
    }

    .metric-title {
      font-size: 0.625rem;
    }

    .metric-value {
      font-size: 1.75rem;
    }

    .metric-label {
      font-size: 0.6875rem;
    }

    .metric-icon {
      width: 36px;
      height: 36px;
    }

    .metric-icon :global(svg) {
      width: 18px;
      height: 18px;
    }
  }
</style>
