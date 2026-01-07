<script lang="ts">
  import { uiStore } from '$lib/stores';
  import Icon from './Icon.svelte';

  interface Props {
    onRefresh: () => void;
  }

  let { onRefresh }: Props = $props();
  let spinning = $state(false);

  const sectionTitles: Record<string, string> = {
    overview: 'Dashboard',
    parser: 'Parser',
    activity: 'Activity',
  };

  const sectionDescriptions: Record<string, string> = {
    overview: 'Metrics, endpoints, and quick start guide',
    parser: 'Tag filtering and output settings',
    activity: 'Request logs and history',
  };

  const currentTitle = $derived(sectionTitles[uiStore.activeSection] || 'Dashboard');
  const currentDescription = $derived(sectionDescriptions[uiStore.activeSection] || '');

  async function handleRefresh() {
    spinning = true;
    await onRefresh();
    setTimeout(() => spinning = false, 500);
  }

  function openMobileMenu() {
    uiStore.toggleMobileMenu();
  }
</script>

<header class="topbar">
  <!-- Mobile hamburger menu button -->
  <button
    class="menu-btn"
    onclick={openMobileMenu}
    aria-label="Open menu"
    aria-expanded={uiStore.mobileMenuOpen}
  >
    <Icon name="menu" size={22} />
  </button>

  <div class="topbar-content">
    <div class="topbar-title-group">
      <h1 class="topbar-title">{currentTitle}</h1>
      {#if currentDescription}
        <p class="topbar-description">{currentDescription}</p>
      {/if}
    </div>
  </div>

  <div class="topbar-actions">
    <button
      class="btn btn-ghost"
      onclick={handleRefresh}
      title="Refresh data"
      aria-label="Refresh data"
    >
      <svg
        class="refresh-icon"
        class:spinning
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        aria-hidden="true"
      >
        <path d="M21 12a9 9 0 10-3.2 6.8"/>
        <path d="M21 12v6h-6"/>
      </svg>
      <span class="btn-text">Refresh</span>
    </button>
  </div>
</header>

<style>
  .topbar {
    position: sticky;
    top: 0;
    z-index: 40;
    background: var(--bg-base);
    border-bottom: 1px solid var(--border-subtle);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-lg) var(--space-2xl);
    gap: var(--space-md);
  }

  /* Mobile menu button - hidden on desktop */
  .menu-btn {
    display: none;
    width: 40px;
    height: 40px;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--text-secondary);
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: color var(--duration-fast), background-color var(--duration-fast);
    -webkit-tap-highlight-color: transparent;
    flex-shrink: 0;
  }

  .menu-btn:hover {
    color: var(--text-primary);
    background: var(--bg-hover);
  }

  .menu-btn:active {
    background: var(--bg-active);
  }

  .topbar-content {
    flex: 1;
    min-width: 0;
  }

  .topbar-title-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .topbar-title {
    font-size: 1.5rem;
    font-weight: 600;
    color: var(--text-primary);
    letter-spacing: -0.02em;
    line-height: 1.2;
  }

  .topbar-description {
    font-size: 0.875rem;
    color: var(--text-muted);
    font-weight: 400;
  }

  .topbar-actions {
    display: flex;
    gap: var(--space-sm);
    flex-shrink: 0;
  }

  .refresh-icon {
    transition: transform var(--duration-fast);
  }

  .refresh-icon.spinning {
    animation: spin 0.8s linear infinite;
  }

  .btn-text {
    font-weight: 500;
  }

  /* Tablet breakpoint */
  @media (max-width: 1023px) {
    .topbar {
      padding: var(--space-md) var(--space-xl);
    }
  }

  /* Mobile breakpoint */
  @media (max-width: 767px) {
    .topbar {
      padding: var(--space-sm) var(--space-md);
      gap: var(--space-sm);
    }

    .menu-btn {
      display: flex;
    }

    .topbar-title {
      font-size: 1.125rem;
    }

    .topbar-description {
      display: none;
    }

    .btn-text {
      display: none;
    }

    .topbar-actions .btn {
      padding: 0.5rem;
    }
  }

  /* Small mobile breakpoint */
  @media (max-width: 479px) {
    .topbar {
      padding: var(--space-xs) var(--space-sm);
    }

    .topbar-title {
      font-size: 1rem;
    }

    .menu-btn {
      width: 36px;
      height: 36px;
    }
  }
</style>
