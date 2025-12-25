<script lang="ts">
  import { onMount } from 'svelte';
  import Sidebar from './lib/components/Sidebar.svelte';
  import Topbar from './lib/components/Topbar.svelte';
  import Overview from './routes/Overview.svelte';
  import Setup from './routes/Setup.svelte';
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
    
    <div class="container">
      {#if uiStore.activeSection === 'overview'}
        <Overview />
      {:else if uiStore.activeSection === 'setup'}
        <Setup />
      {:else if uiStore.activeSection === 'parser'}
        <Parser />
      {:else if uiStore.activeSection === 'activity'}
        <Activity />
      {/if}
    </div>
  </main>
</div>

<Notification />

<style>
  .app-shell {
    display: flex;
    min-height: 100vh;
    position: relative;
    z-index: 2;
  }

  .main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    position: relative;
  }

  .container {
    padding: var(--space-lg);
    max-width: 100%;
  }

  @media (max-width: 768px) {
    .app-shell {
      flex-direction: column;
    }

    .container {
      padding: var(--space-md);
    }
  }
</style>
