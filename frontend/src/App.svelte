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
  let refreshInterval: number;

  onMount(() => {
    // Initialize UI
    uiStore.init();

    // Initial data load
    Promise.all([
      logsStore.refresh(),
      uiStore.refreshEndpoints(),
      parserStore.loadSettings(),
    ]);

    // Auto-refresh every 5 seconds
    refreshInterval = setInterval(() => {
      logsStore.refresh(true);
      uiStore.refreshEndpoints();
    }, 5000);

    return () => {
      clearInterval(refreshInterval);
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

<div class="noise" aria-hidden="true"></div>

<div class="app-shell" class:sidebar-collapsed={uiStore.sidebarCollapsed}>
  <Sidebar />
  
  <main class="main" role="main">
    <Topbar onRefresh={handleRefresh} />
    
    <div class="container">
      <Overview />
      <Setup />
      <Parser />
      <Activity />
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
    animation: fadeInUp 0.5s var(--ease-expo);
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
