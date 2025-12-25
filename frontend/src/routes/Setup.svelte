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
        <div id="openrouterApiHelp" class="help-pop show">
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
  .parameter-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
    gap: var(--space-lg);
    margin-bottom: var(--space-lg);
  }

  .parameter-card {
    background: linear-gradient(135deg, 
      rgba(26, 29, 33, 0.8) 0%, 
      rgba(18, 20, 23, 0.9) 100%);
    padding: var(--space-lg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-subtle);
    box-shadow: var(--shadow-float);
    transition: transform 0.3s var(--ease-smooth), box-shadow 0.3s var(--ease-smooth), border-color 0.3s var(--ease-smooth);
  }

  .parameter-card:hover {
    transform: translateY(-2px);
    box-shadow: var(--shadow-xl);
    border-color: var(--border-default);
  }

  .parameter-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--space-md);
  }

  .parameter-name {
    font-weight: 600;
    color: var(--text-primary);
    font-size: 0.9375rem;
  }

  .input-group {
    display: flex;
    gap: var(--space-sm);
    align-items: stretch;
    width: 100%;
  }

  .copy-input {
    flex: 1;
    padding: var(--space-sm) var(--space-md);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-primary);
    font-size: 0.9375rem;
    font-weight: 500;
    outline: none;
    transition: border-color 0.2s var(--ease-smooth), background-color 0.2s var(--ease-smooth), box-shadow 0.2s var(--ease-smooth);
    font-family: inherit;
  }

  .copy-input.glow-highlight {
    border-color: var(--border-interactive);
    box-shadow: 0 0 0 2px rgba(0, 212, 255, 0.15), 0 0 24px rgba(0, 212, 255, 0.25);
    animation: endpointGlow 1.2s var(--ease-smooth);
  }

  @keyframes endpointGlow {
    0% { box-shadow: 0 0 0 0 rgba(0, 212, 255, 0.0); }
    50% { box-shadow: 0 0 0 2px rgba(0, 212, 255, 0.20), 0 0 24px rgba(0, 212, 255, 0.30); }
    100% { box-shadow: 0 0 0 2px rgba(0, 212, 255, 0.10), 0 0 20px rgba(0, 212, 255, 0.15); }
  }

  .metric-label {
    font-size: 0.875rem;
    color: var(--text-tertiary);
    font-weight: 500;
    margin-top: 0.5rem;
  }

  .toolbar-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    padding: 0.4rem 0.75rem;
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    background: rgba(255, 255, 255, 0.02);
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.875rem;
    line-height: 1.1;
    cursor: pointer;
    transition: all 0.2s var(--ease-smooth);
  }

  .toolbar-btn:hover:not(:disabled) {
    border-color: var(--border-interactive);
    background: rgba(255, 255, 255, 0.04);
    color: var(--text-primary);
  }

  .toolbar-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .toolbar-btn--accent {
    border-color: var(--border-interactive);
    color: var(--accent-primary);
  }

  .toolbar-btn--accent:hover:not(:disabled) {
    background: rgba(0, 212, 255, 0.06);
  }

  .btn-icon {
    width: 16px;
    height: 16px;
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
    transition: all 0.2s var(--ease-smooth);
    z-index: 2;
  }

  .help-badge:hover {
    border-color: var(--border-interactive);
    background: rgba(255, 255, 255, 0.06);
    transform: translateY(-1px) scale(1.05);
  }

  .help-pop {
    margin-top: var(--space-sm);
    color: var(--text-tertiary);
    padding: var(--space-sm) var(--space-md);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    background: rgba(255, 255, 255, 0.02);
    box-shadow: var(--shadow-sm);
    animation: fadeInScale 0.2s var(--ease-expo);
  }

  @keyframes fadeInScale {
    from { opacity: 0; transform: scale(0.8); }
    to { opacity: 1; transform: scale(1); }
  }

  @media (max-width: 1280px) {
    .parameter-grid {
      grid-template-columns: 1fr;
    }
  }
</style>

