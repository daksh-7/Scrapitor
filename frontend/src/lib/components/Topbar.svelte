<script lang="ts">
  import { uiStore } from '$lib/stores';

  interface Props {
    onRefresh: () => void;
  }

  let { onRefresh }: Props = $props();
  let spinning = $state(false);

  async function handleRefresh() {
    spinning = true;
    await onRefresh();
    setTimeout(() => spinning = false, 500);
  }
</script>

<header class="topbar backdrop">
  <h1 class="topbar-title">Dashboard</h1>
  
  <div class="topbar-actions action-bar">
    <button 
      class="toolbar-btn" 
      onclick={() => uiStore.toggleSidebar()}
      title="Toggle sidebar" 
      aria-label="Toggle sidebar"
    >
      <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <rect x="3" y="4" width="6" height="16" rx="1"/>
        <rect x="11" y="4" width="10" height="16" rx="2"/>
      </svg>
      <span class="btn-label">Sidebar</span>
    </button>
    
    <button 
      class="toolbar-btn" 
      onclick={() => uiStore.toggleDensity()}
      title="Toggle density" 
      aria-label="Toggle compact density"
    >
      <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <path d="M5 7h14" stroke-linecap="round"/>
        <path d="M7 12h10" stroke-linecap="round"/>
        <path d="M9 17h6" stroke-linecap="round"/>
      </svg>
      <span class="btn-label">{uiStore.compactMode ? 'Normal' : 'Compact'}</span>
    </button>
    
    <button 
      class="toolbar-btn toolbar-btn--accent" 
      onclick={handleRefresh}
      title="Refresh data" 
      aria-label="Refresh data"
    >
      <svg 
        class="btn-icon" 
        class:spinning
        viewBox="0 0 24 24" 
        fill="none" 
        stroke="currentColor" 
        stroke-width="2" 
        aria-hidden="true"
      >
        <path d="M21 12a9 9 0 10-3.2 6.8" stroke-linecap="round"/>
        <path d="M21 12v6h-6" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      <span class="btn-label">Refresh</span>
    </button>
  </div>
</header>

<style>
  .topbar {
    position: sticky;
    top: 0;
    z-index: 40;
    background: linear-gradient(180deg, 
      rgba(15, 17, 20, 0.9) 0%, 
      rgba(10, 11, 13, 0.95) 100%);
    backdrop-filter: blur(20px) saturate(180%);
    -webkit-backdrop-filter: blur(20px) saturate(180%);
    border-bottom: 1px solid var(--border-subtle);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-md) var(--space-lg);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.2);
  }

  .topbar-title {
    font-size: 1.25rem;
    font-weight: 700;
    background: linear-gradient(135deg, var(--text-primary) 0%, var(--text-secondary) 100%);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    letter-spacing: -0.02em;
  }

  .topbar-actions {
    display: flex;
    gap: var(--space-sm);
  }

  .action-bar {
    display: flex;
    gap: var(--space-sm);
    align-items: center;
    flex-wrap: wrap;
  }

  .toolbar-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    padding: 0.4rem 0.75rem;
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.875rem;
    line-height: 1.1;
    cursor: pointer;
    transition: border-color 0.2s var(--ease-smooth), background-color 0.2s var(--ease-smooth), color 0.2s var(--ease-smooth), box-shadow 0.2s var(--ease-smooth), transform 0.2s var(--ease-smooth);
  }

  .toolbar-btn:hover {
    border-color: var(--border-interactive);
    background: rgba(255, 255, 255, 0.04);
    color: var(--text-primary);
    box-shadow: var(--shadow-sm);
  }

  .toolbar-btn:active {
    transform: translateY(0.5px);
  }

  .toolbar-btn--accent {
    border-color: var(--border-interactive);
    color: var(--accent-primary);
  }

  .toolbar-btn--accent:hover {
    background: rgba(0, 212, 255, 0.06);
    box-shadow: 0 0 0 2px rgba(0, 212, 255, 0.08);
  }

  .btn-icon {
    width: 16px;
    height: 16px;
    flex: 0 0 auto;
    display: inline-block;
  }

  .btn-icon.spinning {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  @media (max-width: 768px) {
    .topbar {
      padding: var(--space-md);
    }

    .btn-label {
      display: none;
    }
  }
</style>

