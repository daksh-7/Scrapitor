<script lang="ts">
  import Section from '$lib/components/Section.svelte';
  import MetricCard from '$lib/components/MetricCard.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { logsStore, uiStore } from '$lib/stores';
</script>

<div class="overview-page">
  <div class="metrics-grid">
    <MetricCard 
      title="Total Requests" 
      value={logsStore.total} 
      label="Since startup"
    >
      {#snippet icon()}
        <Icon name="activity" size={20} />
      {/snippet}
    </MetricCard>

    <MetricCard 
      title="All Log Files" 
      value={logsStore.totalAll} 
      label="In logs folder"
    >
      {#snippet icon()}
        <Icon name="grid" size={20} />
      {/snippet}
    </MetricCard>

    <MetricCard 
      title="Parsed Texts" 
      value={logsStore.parsedTotal} 
      label="All versions"
    >
      {#snippet icon()}
        <Icon name="layers" size={20} />
      {/snippet}
    </MetricCard>

    <MetricCard 
      title="Server Port" 
      value={uiStore.port} 
      label="Listening on"
    >
      {#snippet icon()}
        <Icon name="server" size={20} />
      {/snippet}
    </MetricCard>
  </div>

  {#if uiStore.cloudflareUrl}
    <Section id="endpoints">
      <div class="endpoints-row">
        <div class="endpoint-card">
          <div class="endpoint-header">
            <span class="endpoint-label">Cloudflare Tunnel</span>
            <span class="endpoint-status">
              <span class="status-dot status-dot--pulse"></span>
              Active
            </span>
          </div>
          <code class="endpoint-url">{uiStore.cloudflareUrl}</code>
        </div>
        <div class="endpoint-card">
          <div class="endpoint-header">
            <span class="endpoint-label">Local Server</span>
            <span class="endpoint-status">
              <span class="status-dot"></span>
              Active
            </span>
          </div>
          <code class="endpoint-url">{uiStore.localUrl}</code>
        </div>
      </div>
    </Section>
  {/if}
</div>

<style>
  .overview-page {
    animation: fadeInUp var(--duration-normal) var(--ease-out);
  }

  .metrics-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: var(--space-lg);
    margin-bottom: var(--space-xl);
  }

  .metrics-grid > :global(*) {
    opacity: 0;
    animation: fadeInUp var(--duration-normal) var(--ease-out) forwards;
  }

  .metrics-grid > :global(*:nth-child(1)) { animation-delay: 0.05s; }
  .metrics-grid > :global(*:nth-child(2)) { animation-delay: 0.1s; }
  .metrics-grid > :global(*:nth-child(3)) { animation-delay: 0.15s; }
  .metrics-grid > :global(*:nth-child(4)) { animation-delay: 0.2s; }

  .endpoints-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
    gap: var(--space-lg);
  }

  .endpoint-card {
    background: var(--bg-elevated);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-lg);
    padding: var(--space-lg) var(--space-xl);
  }

  .endpoint-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: var(--space-md);
  }

  .endpoint-label {
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-muted);
  }

  .endpoint-status {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--accent);
  }

  .endpoint-url {
    display: block;
    font-family: 'Geist Mono', monospace;
    font-size: 0.9375rem;
    color: var(--text-secondary);
    word-break: break-all;
    line-height: 1.5;
  }

  @media (max-width: 640px) {
    .metrics-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
