<script lang="ts">
  import { uiStore } from '$lib/stores';
  import Icon from './Icon.svelte';

  const navItems = [
    { id: 'overview', label: 'Dashboard', icon: 'home' as const },
    { id: 'parser', label: 'Parser', icon: 'layers' as const },
    { id: 'activity', label: 'Activity', icon: 'activity' as const },
  ];

  function navigateTo(id: string) {
    uiStore.setActiveSection(id);
  }
</script>

<nav class="mobile-nav" aria-label="Mobile navigation">
  {#each navItems as item}
    <button
      class="mobile-nav-item"
      class:active={uiStore.activeSection === item.id}
      onclick={() => navigateTo(item.id)}
      aria-current={uiStore.activeSection === item.id ? 'page' : undefined}
    >
      <Icon name={item.icon} size={22} />
      <span>{item.label}</span>
    </button>
  {/each}
</nav>

<style>
  .mobile-nav {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    height: calc(var(--mobile-nav-height) + var(--safe-area-bottom));
    padding-bottom: var(--safe-area-bottom);
    background: var(--bg-surface);
    border-top: 1px solid var(--border-subtle);
    display: none;
    align-items: stretch;
    justify-content: space-around;
    z-index: 100;
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
  }

  @media (max-width: 767px) {
    .mobile-nav {
      display: flex;
    }
  }

  .mobile-nav-item {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 4px;
    background: transparent;
    border: none;
    color: var(--text-muted);
    font-size: 0.6875rem;
    font-weight: 500;
    cursor: pointer;
    transition: color var(--duration-fast), transform var(--duration-fast);
    -webkit-tap-highlight-color: transparent;
    position: relative;
    padding: 0;
  }

  .mobile-nav-item::before {
    content: '';
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%) scaleX(0);
    width: 32px;
    height: 3px;
    background: var(--accent);
    border-radius: 0 0 var(--radius-sm) var(--radius-sm);
    transition: transform var(--duration-fast) var(--ease-out);
  }

  .mobile-nav-item.active::before {
    transform: translateX(-50%) scaleX(1);
  }

  .mobile-nav-item:active {
    transform: scale(0.95);
  }

  .mobile-nav-item.active {
    color: var(--accent);
  }

  .mobile-nav-item span {
    letter-spacing: 0.02em;
  }
</style>
