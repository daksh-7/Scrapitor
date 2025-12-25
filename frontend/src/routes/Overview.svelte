<script lang="ts">
  import Section from '$lib/components/Section.svelte';
  import MetricCard from '$lib/components/MetricCard.svelte';
  import { logsStore, uiStore } from '$lib/stores';
</script>

<Section id="overview" title="Overview">
  <div class="metrics-grid">
    <MetricCard 
      title="Total Requests" 
      value={logsStore.total} 
      label="Since startup"
    >
      {#snippet icon()}
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
        </svg>
      {/snippet}
    </MetricCard>

    <MetricCard 
      title="All Log Files" 
      value={logsStore.totalAll} 
      label="In logs folder"
    >
      {#snippet icon()}
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="3" y="3" width="7" height="7" rx="1"/>
          <rect x="14" y="3" width="7" height="7" rx="1"/>
          <rect x="3" y="14" width="7" height="7" rx="1"/>
          <rect x="14" y="14" width="7" height="7" rx="1"/>
        </svg>
      {/snippet}
    </MetricCard>

    <MetricCard 
      title="Parsed Texts" 
      value={logsStore.parsedTotal} 
      label="All versions"
    >
      {#snippet icon()}
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 20l9-5-9-5-9 5 9 5z"/>
          <path d="M3 10l9-5 9 5"/>
        </svg>
      {/snippet}
    </MetricCard>

    <MetricCard 
      title="Server Port" 
      value={uiStore.port} 
      label="Listening on"
    >
      {#snippet icon()}
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="4" y="4" width="16" height="16" rx="2"/>
          <rect x="9" y="9" width="6" height="6"/>
        </svg>
      {/snippet}
    </MetricCard>
  </div>
</Section>

<style>
  .metrics-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
    gap: var(--space-lg);
    margin-bottom: var(--space-lg);
  }

  @media (max-width: 768px) {
    .metrics-grid {
      grid-template-columns: 1fr;
    }
  }
</style>

