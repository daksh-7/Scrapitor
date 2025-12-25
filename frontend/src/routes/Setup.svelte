<script lang="ts">
  import Section from '$lib/components/Section.svelte';
  import { uiStore } from '$lib/stores';

  let helpVisible = $state(false);

  async function copyText(text: string) {
    await uiStore.copyToClipboard(text);
  }
</script>

<Section id="setup" title="Setup">
  <div class="parameter-grid">
    <div class="parameter-card">
      <div class="parameter-header">
        <span class="parameter-name">Model Name Preset</span>
      </div>
      <div class="input-group">
        <input 
          type="text" 
          class="copy-input" 
          value="mistralai/devstral-2512:free" 
          readonly 
          aria-label="Model Name Preset" 
        />
        <button 
          class="toolbar-btn toolbar-btn--accent" 
          onclick={() => copyText('mistralai/devstral-2512:free')}
          aria-label="Copy model name"
        >
          <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <rect x="9" y="9" width="13" height="13" rx="2"/>
            <rect x="2" y="2" width="13" height="13" rx="2"/>
          </svg>
          <span class="btn-label">Copy</span>
        </button>
      </div>
      <div class="metric-label">Use this in JanitorAI "Model name"</div>
    </div>

    <div class="parameter-card">
      <div class="parameter-header">
        <span class="parameter-name">Cloudflare Endpoint</span>
      </div>
      <div class="input-group">
        <input 
          type="text" 
          class="copy-input" 
          class:glow-highlight={uiStore.cloudflareUrl}
          value={uiStore.cloudflareUrl || 'Not available'} 
          readonly 
          aria-label="Cloudflare Endpoint" 
        />
        <button 
          class="toolbar-btn toolbar-btn--accent" 
          onclick={() => copyText(uiStore.cloudflareUrl)}
          disabled={!uiStore.cloudflareUrl}
          aria-label="Copy Cloudflare Endpoint"
        >
          <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <rect x="9" y="9" width="13" height="13" rx="2"/>
            <rect x="2" y="2" width="13" height="13" rx="2"/>
          </svg>
          <span class="btn-label">Copy</span>
        </button>
      </div>
      <div class="metric-label">Public URL via cloudflared</div>
    </div>

    <div class="parameter-card">
      <div class="parameter-header">
        <span class="parameter-name">Local Endpoint</span>
      </div>
      <div class="input-group">
        <input 
          type="text" 
          class="copy-input" 
          value={uiStore.localUrl} 
          readonly 
          aria-label="Local Endpoint" 
        />
        <button 
          class="toolbar-btn toolbar-btn--accent" 
          onclick={() => copyText(uiStore.localUrl)}
          aria-label="Copy Local Endpoint"
        >
          <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <rect x="9" y="9" width="13" height="13" rx="2"/>
            <rect x="2" y="2" width="13" height="13" rx="2"/>
          </svg>
          <span class="btn-label">Copy</span>
        </button>
      </div>
      <div class="metric-label">Direct URL (this machine)</div>
    </div>
  </div>

  <ol class="setup-steps">
    <li>Open your character chat in JanitorAI.</li>
    <li>Turn on Using proxy and create a new proxy profile.</li>
    <li>Model name: <code>mistralai/devstral-2512:free</code>.</li>
    <li>Proxy URL: paste the Cloudflare endpoint shown above.</li>
    <li>
      API Key: paste your OpenRouter
      <span class="inline-help-anchor">
        key
        <button 
          type="button" 
          class="help-badge" 
          onclick={() => helpVisible = !helpVisible}
          aria-expanded={helpVisible}
          aria-controls="openrouterApiHelp" 
          title="How to get API key"
        >?</button>
      </span>.
      {#if helpVisible}
        <div id="openrouterApiHelp" class="help-pop">
          Log in at
          <a href="https://openrouter.ai" target="_blank" rel="noreferrer noopener">openrouter.ai</a>,
          open <strong>Keys</strong> from your profile menu, click <strong>Create API Key</strong>, then copy it.
        </div>
      {/if}
    </li>
    <li>Save changes and Save Settings in JanitorAI, then refresh this page.</li>
    <li>Send a quick test message (e.g., Hi) to verify the connection.</li>
  </ol>
</Section>

<style>
  .copy-input.glow-highlight {
    border-color: var(--border-interactive);
  }

  .setup-steps {
    margin: var(--space-lg) 0;
    padding-left: var(--space-md);
    color: var(--text-secondary);
    list-style: none;
    counter-reset: step-counter;
  }

  .setup-steps li {
    margin: var(--space-md) 0;
    position: relative;
    padding-left: calc(var(--space-lg) + 12px);
    counter-increment: step-counter;
    line-height: 1.55;
  }

  .setup-steps li::before {
    content: counter(step-counter);
    position: absolute;
    left: 0;
    top: 0.05rem;
    width: 22px;
    height: 22px;
    border-radius: var(--radius-full);
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.75rem;
  }

  .setup-steps code {
    background: rgba(0, 212, 255, 0.1);
    padding: 0.1em 0.4em;
    border-radius: var(--radius-sm);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.875em;
    color: var(--accent-primary);
  }

  .setup-steps a {
    color: var(--accent-primary);
    text-decoration: none;
    font-weight: 500;
  }

  .setup-steps a:hover {
    color: var(--accent-primary-bright);
    text-decoration: underline;
  }

  .inline-help-anchor {
    position: relative;
    display: inline-block;
  }

  .help-badge {
    position: absolute;
    top: -0.9em;
    right: -1.1em;
    width: 1.35em;
    height: 1.35em;
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-primary);
    line-height: 1.35em;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 0.85em;
    cursor: pointer;
    transition: border-color 0.15s, background-color 0.15s;
    z-index: 2;
  }

  .help-badge:hover {
    border-color: var(--border-interactive);
    background: rgba(255, 255, 255, 0.06);
  }

  .help-pop {
    margin-top: var(--space-sm);
    color: var(--text-tertiary);
    padding: var(--space-sm) var(--space-md);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    background: rgba(255, 255, 255, 0.02);
    animation: fadeIn 0.15s var(--ease-smooth);
  }
</style>
