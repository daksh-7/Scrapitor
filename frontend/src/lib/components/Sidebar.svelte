<script lang="ts">
  import { uiStore } from '$lib/stores';
  import Icon from './Icon.svelte';

  const navItems = [
    { id: 'overview', label: 'Dashboard', icon: 'home' as const },
    { id: 'parser', label: 'Parser', icon: 'layers' as const },
    { id: 'activity', label: 'Activity', icon: 'activity' as const },
  ];

  let collapsed = $state(false);

  function navigateTo(id: string) {
    uiStore.setActiveSection(id);
  }

  function openCloudflare() {
    if (uiStore.cloudflareUrl) {
      window.open(uiStore.cloudflareUrl.replace('/openrouter-cc', '/'), '_blank');
    }
  }

  function openLocal() {
    window.open(uiStore.localUrl.replace('/openrouter-cc', '/'), '_blank');
  }

  function toggleCollapse() {
    collapsed = !collapsed;
  }

  function handleBackdropClick() {
    uiStore.closeMobileMenu();
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && uiStore.mobileMenuOpen) {
      uiStore.closeMobileMenu();
    }
  }
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- Mobile backdrop -->
{#if uiStore.mobileMenuOpen}
  <button
    class="mobile-backdrop"
    onclick={handleBackdropClick}
    aria-label="Close menu"
  ></button>
{/if}

<aside
  class="sidebar"
  class:collapsed
  class:mobile-open={uiStore.mobileMenuOpen}
  aria-label="Main navigation"
>
  <div class="sidebar-header">
    <div class="brand" aria-label="Scrapitor - Local OpenRouter Gateway">
      <div class="logo">
        <img src="/static/assets/logo.svg" alt="" class="logo-img" />
      </div>
      {#if !collapsed}
        <div class="brand-text">
          <span class="brand-name">Scrapitor</span>
        </div>
      {/if}
    </div>
    <button
      class="collapse-btn hide-mobile"
      onclick={toggleCollapse}
      aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
      title={collapsed ? 'Expand' : 'Collapse'}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        {#if collapsed}
          <path d="M9 18l6-6-6-6"/>
        {:else}
          <path d="M15 18l-6-6 6-6"/>
        {/if}
      </svg>
    </button>
    <!-- Mobile close button -->
    <button
      class="close-btn show-mobile"
      onclick={handleBackdropClick}
      aria-label="Close menu"
    >
      <Icon name="close" size={20} />
    </button>
  </div>

  <nav class="nav" aria-label="Primary">
    {#each navItems as item}
      <button
        class="nav-item"
        class:active={uiStore.activeSection === item.id}
        onclick={() => navigateTo(item.id)}
        aria-current={uiStore.activeSection === item.id ? 'page' : undefined}
        title={collapsed ? item.label : undefined}
      >
        <Icon name={item.icon} size={18} />
        {#if !collapsed}
          <span class="nav-label">{item.label}</span>
        {/if}
      </button>
    {/each}
  </nav>

  <div class="sidebar-footer">
    {#if !collapsed}
      <div class="quick-links">
        <button
          class="link-btn"
          onclick={openCloudflare}
          disabled={!uiStore.cloudflareUrl}
          title={uiStore.cloudflareUrl || 'Not available'}
        >
          <Icon name="externalLink" size={14} />
          <span>Cloudflare</span>
        </button>
        <button
          class="link-btn"
          onclick={openLocal}
          title={uiStore.localUrl}
        >
          <Icon name="externalLink" size={14} />
          <span>Local</span>
        </button>
      </div>
    {:else}
      <div class="quick-links-collapsed">
        <button
          class="link-btn-icon"
          onclick={openCloudflare}
          disabled={!uiStore.cloudflareUrl}
          title="Open Cloudflare URL"
        >
          <Icon name="externalLink" size={16} />
        </button>
      </div>
    {/if}
  </div>
</aside>

<style>
  /* Mobile backdrop overlay */
  .mobile-backdrop {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
    z-index: 90;
    border: none;
    cursor: pointer;
    animation: fadeIn var(--duration-fast) var(--ease-out);
  }

  @media (max-width: 767px) {
    .mobile-backdrop {
      display: block;
    }
  }

  .sidebar {
    width: 240px;
    flex: 0 0 240px;
    background: var(--bg-surface);
    border-right: 1px solid var(--border-subtle);
    display: flex;
    flex-direction: column;
    position: sticky;
    top: 0;
    height: 100vh;
    overflow-y: auto;
    transition: width var(--duration-normal) var(--ease-out),
                flex-basis var(--duration-normal) var(--ease-out);
  }

  .sidebar.collapsed {
    width: 64px;
    flex: 0 0 64px;
  }

  .sidebar-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-lg);
    border-bottom: 1px solid var(--border-subtle);
  }

  .collapsed .sidebar-header {
    flex-direction: column;
    gap: var(--space-sm);
    padding: var(--space-md);
  }

  .brand {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    min-width: 0;
  }

  .logo {
    width: 36px;
    height: 36px;
    min-width: 36px;
    background: var(--bg-elevated);
    border-radius: var(--radius-md);
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    border: 1px solid var(--border-subtle);
  }

  .logo-img {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }

  .brand-text {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    min-width: 0;
  }

  .brand-name {
    font-size: 1.0625rem;
    font-weight: 600;
    color: var(--text-primary);
    letter-spacing: -0.02em;
    white-space: nowrap;
  }

  .collapse-btn {
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--text-muted);
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: color var(--duration-fast), background-color var(--duration-fast);
  }

  .collapse-btn:hover {
    color: var(--text-primary);
    background: var(--bg-hover);
  }

  .collapsed .collapse-btn {
    width: 32px;
    height: 32px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-subtle);
  }

  .collapsed .collapse-btn:hover {
    background: var(--bg-hover);
    border-color: var(--border-default);
  }

  /* Mobile close button */
  .close-btn {
    display: none;
    width: 36px;
    height: 36px;
    align-items: center;
    justify-content: center;
    border: none;
    background: var(--bg-hover);
    color: var(--text-secondary);
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: color var(--duration-fast), background-color var(--duration-fast);
    -webkit-tap-highlight-color: transparent;
  }

  .close-btn:hover {
    color: var(--text-primary);
    background: var(--bg-active);
  }

  .nav {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: var(--space-sm);
    overflow-y: auto;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: var(--space-md);
    padding: var(--space-md) var(--space-lg);
    border-radius: var(--radius-md);
    color: var(--text-muted);
    font-weight: 500;
    font-size: 0.9375rem;
    border: none;
    background: transparent;
    cursor: pointer;
    transition:
      color var(--duration-fast),
      background-color var(--duration-fast);
    text-align: left;
    width: 100%;
    white-space: nowrap;
    -webkit-tap-highlight-color: transparent;
  }

  .collapsed .nav-item {
    justify-content: center;
    padding: var(--space-sm);
  }

  .nav-item:hover {
    color: var(--text-primary);
    background: var(--bg-hover);
  }

  .nav-item.active {
    color: var(--accent);
    background: var(--accent-subtle);
  }

  .nav-item.active:hover {
    background: var(--accent-subtle);
  }

  .nav-label {
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .sidebar-footer {
    padding: var(--space-sm);
    border-top: 1px solid var(--border-subtle);
  }

  .quick-links {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .link-btn {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    padding: var(--space-xs) var(--space-sm);
    border: none;
    background: transparent;
    color: var(--text-muted);
    font-size: 0.75rem;
    font-weight: 500;
    cursor: pointer;
    border-radius: var(--radius-sm);
    transition: color var(--duration-fast), background-color var(--duration-fast);
    text-align: left;
    width: 100%;
    -webkit-tap-highlight-color: transparent;
  }

  .link-btn:hover:not(:disabled) {
    color: var(--text-secondary);
    background: var(--bg-hover);
  }

  .link-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .quick-links-collapsed {
    display: flex;
    justify-content: center;
  }

  .link-btn-icon {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--text-muted);
    cursor: pointer;
    border-radius: var(--radius-md);
    transition: color var(--duration-fast), background-color var(--duration-fast);
    -webkit-tap-highlight-color: transparent;
  }

  .link-btn-icon:hover:not(:disabled) {
    color: var(--text-primary);
    background: var(--bg-hover);
  }

  .link-btn-icon:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  /* Hide mobile-specific elements on desktop */
  .hide-mobile {
    display: flex;
  }

  .show-mobile {
    display: none;
  }

  /* ── Mobile styles ───────────────────────────────────────── */
  @media (max-width: 767px) {
    .hide-mobile {
      display: none !important;
    }

    .show-mobile {
      display: flex !important;
    }

    .sidebar {
      position: fixed;
      top: 0;
      left: 0;
      width: 280px;
      max-width: 85vw;
      height: 100vh;
      z-index: 100;
      transform: translateX(-100%);
      transition: transform var(--duration-normal) var(--ease-out);
      border-right: 1px solid var(--border-subtle);
      box-shadow: var(--shadow-xl);
    }

    .sidebar.mobile-open {
      transform: translateX(0);
    }

    .sidebar.collapsed {
      width: 280px;
      max-width: 85vw;
    }

    .collapsed .sidebar-header {
      flex-direction: row;
      padding: var(--space-lg);
    }

    .nav {
      flex-direction: column;
      overflow-y: auto;
      overflow-x: visible;
      flex: 1;
      padding: var(--space-md);
      gap: var(--space-xs);
    }

    .nav-item {
      min-height: var(--touch-target-min);
      padding: var(--space-md) var(--space-lg);
      font-size: 1rem;
    }

    .collapsed .nav-item {
      justify-content: flex-start;
      padding: var(--space-md) var(--space-lg);
    }

    .nav-label {
      display: block !important;
    }

    .sidebar-footer {
      display: block;
      padding: var(--space-md);
      padding-bottom: calc(var(--space-md) + var(--safe-area-bottom));
    }

    .quick-links {
      gap: var(--space-xs);
    }

    .link-btn {
      min-height: var(--touch-target-min);
      padding: var(--space-sm) var(--space-md);
      font-size: 0.875rem;
    }

    .close-btn {
      display: flex;
    }
  }
</style>
