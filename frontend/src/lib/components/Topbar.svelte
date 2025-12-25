<script lang="ts">
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

<header class="topbar">
  <h1 class="topbar-title">Dashboard</h1>
  
  <div class="topbar-actions action-bar">
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
    background: var(--bg-primary);
    border-bottom: 1px solid var(--border-subtle);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-md) var(--space-lg);
  }

  .topbar-title {
    font-size: 1.25rem;
    font-weight: 700;
    color: var(--text-primary);
    letter-spacing: -0.02em;
  }

  .topbar-actions {
    display: flex;
    gap: var(--space-sm);
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
