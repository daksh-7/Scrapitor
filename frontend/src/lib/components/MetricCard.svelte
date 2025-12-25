<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    title: string;
    value: number | string;
    label: string;
    icon?: Snippet;
  }

  let { title, value, label, icon }: Props = $props();

  // Animate number changes
  let displayValue = $state(typeof value === 'number' ? value : 0);
  let prevValue = $state(typeof value === 'number' ? value : 0);

  $effect(() => {
    if (typeof value === 'number' && value !== prevValue) {
      animateValue(prevValue, value);
      prevValue = value;
    }
  });

  function animateValue(start: number, end: number) {
    const duration = 500;
    const range = Math.abs(end - start);
    if (range === 0) {
      displayValue = end;
      return;
    }
    
    const steps = Math.max(1, Math.min(range, 60));
    const stepTime = Math.max(16, Math.floor(duration / steps));
    let step = 0;
    
    const timer = setInterval(() => {
      step += 1;
      const progress = Math.min(1, step / steps);
      displayValue = Math.round(start + (end - start) * progress);
      if (progress >= 1) {
        clearInterval(timer);
        displayValue = end;
      }
    }, stepTime);
  }

  function formatNumber(n: number | string): string {
    if (typeof n === 'string') return n;
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }
</script>

<div class="metric-card" aria-live="polite">
  <div class="metric-header">
    <div>
      <div class="metric-title">{title}</div>
      <div class="metric-value">{formatNumber(typeof value === 'number' ? displayValue : value)}</div>
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
    background: linear-gradient(135deg, 
      rgba(28, 31, 36, 0.8) 0%, 
      rgba(20, 22, 25, 0.9) 100%);
    backdrop-filter: blur(10px);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-subtle);
    padding: var(--space-lg);
    position: relative;
    overflow: hidden;
    box-shadow: var(--shadow-float);
    transition: transform 0.3s var(--ease-expo), box-shadow 0.3s var(--ease-expo), border-color 0.3s var(--ease-expo);
  }

  .metric-card::before {
    content: '';
    position: absolute;
    inset: 0;
    background: radial-gradient(circle at top right, 
      rgba(0, 212, 255, 0.1) 0%, 
      transparent 70%);
    opacity: 0;
    transition: opacity 0.3s;
  }

  .metric-card:hover {
    transform: translateY(-4px) scale(1.02);
    box-shadow: 
      var(--shadow-2xl),
      0 0 40px rgba(0, 212, 255, 0.1);
    border-color: var(--border-interactive);
  }

  .metric-card:hover::before {
    opacity: 1;
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
    background: linear-gradient(135deg, 
      rgba(0, 212, 255, 0.1) 0%, 
      rgba(0, 255, 136, 0.1) 100%);
    color: var(--accent-primary);
  }

  .metric-icon :global(svg) {
    width: 24px;
    height: 24px;
  }

  :global(body.compact) .metric-card {
    padding: var(--space-md);
  }
</style>

