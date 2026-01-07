<script lang="ts">
  import { onMount } from 'svelte';
  import Sidebar from './lib/components/Sidebar.svelte';
  import Topbar from './lib/components/Topbar.svelte';
  import MobileNav from './lib/components/MobileNav.svelte';
  import Overview from './routes/Overview.svelte';
  import Parser from './routes/Parser.svelte';
  import Activity from './routes/Activity.svelte';
  import Notification from './lib/components/Notification.svelte';
  import { uiStore, logsStore, parserStore } from './lib/stores';

  // Refresh interval
  let refreshInterval: number | undefined;
  const REFRESH_INTERVAL_MS = 5000;

  function startPolling() {
    if (refreshInterval) return;
    refreshInterval = setInterval(() => {
      logsStore.refresh(true);
      uiStore.refreshEndpoints();
    }, REFRESH_INTERVAL_MS);
  }

  function stopPolling() {
    if (refreshInterval) {
      clearInterval(refreshInterval);
      refreshInterval = undefined;
    }
  }

  function handleVisibilityChange() {
    if (document.hidden) {
      stopPolling();
    } else {
      // Refresh immediately when tab becomes visible, then resume polling
      logsStore.refresh(true);
      uiStore.refreshEndpoints();
      startPolling();
    }
  }

  onMount(() => {
    // Initial data load
    Promise.all([
      logsStore.refresh(),
      uiStore.refreshEndpoints(),
      parserStore.loadSettings(),
    ]);

    // Start polling and listen for visibility changes
    startPolling();
    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      stopPolling();
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  });

  async function handleRefresh() {
    await Promise.all([
      logsStore.refresh(),
      uiStore.refreshEndpoints(),
    ]);
    uiStore.notify('Data refreshed');
  }
</script>

<div class="app-shell">
  <Sidebar />

  <main class="main">
    <Topbar onRefresh={handleRefresh} />

    <div class="content">
      {#key uiStore.activeSection}
        <div class="page">
          {#if uiStore.activeSection === 'overview'}
            <Overview />
          {:else if uiStore.activeSection === 'parser'}
            <Parser />
          {:else if uiStore.activeSection === 'activity'}
            <Activity />
          {/if}
        </div>
      {/key}
    </div>
  </main>

  <!-- Mobile bottom navigation -->
  <MobileNav />
</div>

<Notification />

<style>
  .app-shell {
    display: flex;
    min-height: 100vh;
    min-height: 100dvh; /* Dynamic viewport height for mobile */
  }

  .main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    background: var(--bg-base);
  }

  .content {
    flex: 1;
    padding: var(--space-xl) var(--space-2xl);
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }

  .page {
    max-width: 1400px;
    margin: 0 auto;
  }

  /* Tablet breakpoint */
  @media (max-width: 1023px) {
    .content {
      padding: var(--space-lg) var(--space-xl);
    }
  }

  /* Mobile breakpoint */
  @media (max-width: 767px) {
    .app-shell {
      flex-direction: column;
    }

    .main {
      /* Account for bottom navigation */
      padding-bottom: calc(var(--mobile-nav-height) + var(--safe-area-bottom));
    }

    .content {
      padding: var(--space-md);
      padding-bottom: var(--space-lg);
    }
  }

  /* Small mobile breakpoint */
  @media (max-width: 479px) {
    .content {
      padding: var(--space-sm);
      padding-bottom: var(--space-md);
    }
  }
</style>
