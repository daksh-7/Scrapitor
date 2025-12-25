<script lang="ts">
  import { uiStore } from '$lib/stores';

  const navItems = [
    { id: 'overview', label: 'Overview', icon: 'home' },
    { id: 'setup', label: 'Setup', icon: 'settings' },
    { id: 'parser', label: 'Parser', icon: 'list' },
    { id: 'activity', label: 'Activity', icon: 'clock' },
  ];

  function scrollToSection(id: string) {
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      uiStore.setActiveSection(id);
    }
  }

  function openCloudflare() {
    if (uiStore.cloudflareUrl) {
      window.open(uiStore.cloudflareUrl.replace('/openrouter-cc', '/'), '_blank');
    }
  }

  function openLocal() {
    window.open(uiStore.localUrl.replace('/openrouter-cc', '/'), '_blank');
  }
</script>

<aside class="sidebar backdrop" class:collapsed={uiStore.sidebarCollapsed} aria-label="Sidebar">
  <div class="brand" aria-label="Scrapitor - Local OpenRouter Gateway">
    <div class="logo-icon shine" aria-hidden="true">
      <img class="logo-img" src="/assets/logo.png" alt="Scrapitor logo" />
    </div>
    <div class="brand-meta">
      <div class="brand-title">Scrapitor</div>
      <div class="brand-sub">Local OpenRouter Gateway</div>
    </div>
  </div>

  <nav class="nav" role="navigation" aria-label="Primary">
    {#each navItems as item}
      <button
        class="nav-item"
        class:active={uiStore.activeSection === item.id}
        onclick={() => scrollToSection(item.id)}
        aria-current={uiStore.activeSection === item.id ? 'page' : undefined}
      >
        {#if item.icon === 'home'}
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" aria-hidden="true">
            <path d="M3 12l9-9 9 9" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M9 21V9h6v12" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        {:else if item.icon === 'settings'}
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" aria-hidden="true">
            <path d="M12 15.5a3.5 3.5 0 100-7 3.5 3.5 0 000 7z" stroke-width="2"/>
            <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 01-2.83 2.83l-.06-.06A1.65 1.65 0 0015 19.4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        {:else if item.icon === 'list'}
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" aria-hidden="true">
            <path d="M4 6h16M4 12h16M4 18h7" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        {:else if item.icon === 'clock'}
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" aria-hidden="true">
            <circle cx="12" cy="12" r="10" stroke-width="2"/>
            <path d="M12 6v6l4 2" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        {/if}
        <span>{item.label}</span>
      </button>
    {/each}
  </nav>

  <div class="sidebar-footer">
    <button 
      class="ghost-button" 
      onclick={openCloudflare}
      disabled={!uiStore.cloudflareUrl}
      aria-label="Open Cloudflare URL"
    >
      Open Cloudflare
    </button>
    <button class="ghost-button" onclick={openLocal} aria-label="Open Local URL">
      Open Local
    </button>
    <div class="status-badge status-centered" role="status" aria-live="polite">
      <div class="pulse-dot" aria-hidden="true"></div>
      <span>Server Active</span>
      <div class="pulse-dot" aria-hidden="true"></div>
    </div>
  </div>
</aside>

<style>
  .sidebar {
    width: 260px;
    flex: 0 0 260px;
    background: linear-gradient(180deg, 
      rgba(22, 24, 28, 0.8) 0%, 
      rgba(15, 17, 20, 0.9) 100%);
    backdrop-filter: blur(20px) saturate(180%);
    -webkit-backdrop-filter: blur(20px) saturate(180%);
    border-right: 1px solid var(--border-subtle);
    display: flex;
    flex-direction: column;
    padding: var(--space-lg);
    position: sticky;
    top: 0;
    height: 100vh;
    overflow-y: auto;
    transition: width 0.3s var(--ease-smooth), padding 0.3s var(--ease-smooth);
    box-shadow: 4px 0 24px rgba(0, 0, 0, 0.1);
  }

  .sidebar.collapsed {
    width: 80px;
    padding: var(--space-md);
  }

  .brand {
    display: flex;
    align-items: center;
    gap: var(--space-md);
    padding: var(--space-md);
    margin-bottom: var(--space-xl);
    position: relative;
  }

  .logo-icon {
    width: 48px;
    height: 48px;
    min-width: 48px;
    background: linear-gradient(180deg, 
      rgba(22, 24, 28, 0.8) 0%, 
      rgba(15, 17, 20, 0.9) 100%);
    border-radius: var(--radius-lg);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.5rem;
    box-shadow: 
      var(--shadow-md),
      inset 0 0 20px rgba(255, 255, 255, 0.1),
      0 0 40px rgba(0, 212, 255, 0.2);
    position: relative;
    overflow: hidden;
    transition: transform 0.3s var(--ease-expo), box-shadow 0.3s var(--ease-expo);
  }

  .logo-icon .logo-img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    display: block;
    mix-blend-mode: screen;
    filter: brightness(1.15) contrast(1.2);
  }

  .brand-meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
    opacity: 1;
    transition: opacity 0.3s var(--ease-smooth);
  }

  .sidebar.collapsed .brand-meta {
    opacity: 0;
    width: 0;
    overflow: hidden;
  }

  .brand-title {
    font-size: 1.125rem;
    font-weight: 800;
    background: linear-gradient(135deg, var(--text-primary) 0%, var(--text-secondary) 100%);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    letter-spacing: -0.02em;
  }

  .brand-sub {
    font-size: 0.75rem;
    color: var(--text-tertiary);
    font-weight: 500;
    letter-spacing: 0.02em;
    text-transform: uppercase;
  }

  .nav {
    display: flex;
    flex-direction: column;
    gap: var(--space-xs);
    flex: 1;
  }

  .nav-item {
    padding: var(--space-sm) var(--space-md);
    border-radius: var(--radius-md);
    color: var(--text-tertiary);
    text-decoration: none;
    font-weight: 500;
    font-size: 0.9375rem;
    border: 1px solid transparent;
    background: transparent;
    position: relative;
    overflow: hidden;
    transition: color 0.2s var(--ease-smooth), background-color 0.2s var(--ease-smooth), border-color 0.2s var(--ease-smooth), transform 0.2s var(--ease-smooth);
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    cursor: pointer;
    text-align: left;
    width: 100%;
  }

  .nav-item:hover {
    color: var(--text-primary);
    background: rgba(255, 255, 255, 0.03);
    border-color: var(--border-default);
    transform: translateX(4px);
  }

  .nav-item.active {
    color: var(--bg-primary);
    background: linear-gradient(135deg, var(--accent-primary) 0%, var(--accent-secondary) 100%);
    font-weight: 600;
    box-shadow: 
      var(--shadow-md),
      0 0 30px rgba(0, 212, 255, 0.3);
  }

  .sidebar-footer {
    margin-top: auto;
    padding-top: var(--space-lg);
    border-top: 1px solid var(--border-subtle);
  }

  .ghost-button {
    display: block;
    text-align: center;
    padding: var(--space-sm) var(--space-md);
    margin-bottom: var(--space-sm);
    border-radius: var(--radius-md);
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid var(--border-default);
    color: var(--text-secondary);
    text-decoration: none;
    font-weight: 500;
    font-size: 0.875rem;
    transition: background-color 0.2s var(--ease-smooth), border-color 0.2s var(--ease-smooth), color 0.2s var(--ease-smooth), box-shadow 0.2s var(--ease-smooth);
    cursor: pointer;
    width: 100%;
  }

  .ghost-button:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.05);
    border-color: var(--border-interactive);
    color: var(--text-primary);
    box-shadow: 0 0 20px rgba(0, 212, 255, 0.1);
  }

  .ghost-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .status-badge {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    background: linear-gradient(135deg, 
      rgba(0, 255, 136, 0.1) 0%, 
      rgba(0, 255, 136, 0.05) 100%);
    border: 1px solid rgba(0, 255, 136, 0.3);
    padding: var(--space-sm) var(--space-md);
    border-radius: var(--radius-full);
    font-size: 0.8125rem;
    font-weight: 600;
    color: var(--accent-success);
    box-shadow: 0 0 20px rgba(0, 255, 136, 0.15);
    margin-top: 0.75rem;
  }

  .status-centered {
    justify-content: center;
    gap: clamp(1rem, 8vw, 2.25rem);
  }

  .pulse-dot {
    width: 8px;
    height: 8px;
    background: var(--accent-success);
    border-radius: 50%;
    position: relative;
    box-shadow: 0 0 10px var(--accent-success);
  }

  .pulse-dot::before,
  .pulse-dot::after {
    content: '';
    position: absolute;
    inset: 0;
    border-radius: 50%;
    background: var(--accent-success);
    animation: pulse 2s var(--ease-smooth) infinite;
  }

  .pulse-dot::after {
    animation-delay: 1s;
  }

  @keyframes pulse {
    0% {
      transform: scale(1);
      opacity: 1;
    }
    100% {
      transform: scale(3);
      opacity: 0;
    }
  }

  @media (max-width: 768px) {
    .sidebar {
      width: 100%;
      height: auto;
      position: relative;
      border-right: none;
      border-bottom: 1px solid var(--border-subtle);
    }

    .sidebar.collapsed {
      width: 100%;
    }
  }
</style>

