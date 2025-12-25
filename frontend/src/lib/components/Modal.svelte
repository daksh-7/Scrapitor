<script lang="ts">
  import type { Snippet } from 'svelte';
  import { uiStore } from '$lib/stores';

  interface Props {
    open: boolean;
    title: string;
    onClose: () => void;
    onBack?: () => void;
    children: Snippet;
    actions?: Snippet;
  }

  let { open, title, onClose, onBack, children, actions }: Props = $props();

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      onClose();
    }
  }

  async function handleCopy() {
    const body = document.querySelector('.modal-body');
    if (body) {
      await uiStore.copyToClipboard(body.textContent || '');
    }
  }

  // Syntax highlight JSON
  function syntaxHighlight(json: string): string {
    return json
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(
        /("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g,
        (match) => {
          let cls = 'json-number';
          if (/^"/.test(match)) {
            cls = /:$/.test(match) ? 'json-key' : 'json-string';
          } else if (/true|false/.test(match)) {
            cls = 'json-boolean';
          } else if (/null/.test(match)) {
            cls = 'json-null';
          }
          return `<span class="${cls}">${match}</span>`;
        }
      );
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="modalTitle">
    <div class="modal-backdrop" onclick={onClose} aria-hidden="true"></div>
    <div class="modal-panel">
      <div class="modal-header">
        <div class="modal-title" id="modalTitle">{title}</div>
        <div class="modal-actions action-bar">
          {#if onBack}
            <button class="toolbar-btn" onclick={onBack} aria-label="Back">
              <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d="M12 19l-7-7 7-7" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              <span class="btn-label">Back</span>
            </button>
          {/if}
          {#if actions}
            {@render actions()}
          {:else}
            <button class="toolbar-btn" onclick={handleCopy} aria-label="Copy content">
              <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <rect x="9" y="9" width="13" height="13" rx="2"/>
                <rect x="2" y="2" width="13" height="13" rx="2"/>
              </svg>
              <span class="btn-label">Copy</span>
            </button>
          {/if}
          <button class="toolbar-btn toolbar-btn--danger" onclick={onClose} aria-label="Close modal">
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path d="M6 6l12 12M18 6L6 18" stroke-linecap="round"/>
            </svg>
            <span class="btn-label">Close</span>
          </button>
        </div>
      </div>
      <div class="modal-body">
        {@render children()}
      </div>
    </div>
  </div>
{/if}

<style>
  .modal {
    position: fixed;
    inset: 0;
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-lg);
    animation: fadeIn 0.12s var(--ease-smooth);
  }

  .modal-backdrop {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.8);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
  }

  .modal-panel {
    position: relative;
    width: min(900px, 90vw);
    max-height: 85vh;
    background: linear-gradient(135deg, 
      rgba(26, 29, 33, 0.95) 0%, 
      rgba(18, 20, 23, 0.98) 100%);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-xl);
    box-shadow: 
      var(--shadow-2xl),
      0 0 80px rgba(0, 0, 0, 0.5),
      0 0 40px rgba(0, 212, 255, 0.1);
    display: flex;
    flex-direction: column;
    animation: slideUp 0.15s var(--ease-expo);
    overflow: hidden;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-lg);
    border-bottom: 1px solid var(--border-subtle);
    background: rgba(255, 255, 255, 0.02);
  }

  .modal-title {
    font-weight: 700;
    font-size: 1.125rem;
    color: var(--text-primary);
    font-family: 'JetBrains Mono', monospace;
  }

  .modal-actions {
    display: flex;
    gap: var(--space-sm);
  }

  .modal-body {
    padding: var(--space-lg);
    overflow-y: auto;
    flex: 1;
    background: transparent;
    color: var(--text-secondary);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.875rem;
    line-height: 1.7;
    white-space: pre-wrap;
    word-break: break-all;
  }

  .action-bar {
    display: flex;
    gap: var(--space-sm);
    align-items: center;
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
    transition: border-color 0.2s var(--ease-smooth), background-color 0.2s var(--ease-smooth), color 0.2s var(--ease-smooth), box-shadow 0.2s var(--ease-smooth);
  }

  .toolbar-btn:hover {
    border-color: var(--border-interactive);
    background: rgba(255, 255, 255, 0.04);
    color: var(--text-primary);
  }

  .toolbar-btn--danger {
    color: var(--accent-danger);
    border-color: rgba(255, 51, 102, 0.35);
  }

  .toolbar-btn--danger:hover {
    background: rgba(255, 51, 102, 0.08);
  }

  .btn-icon {
    width: 16px;
    height: 16px;
  }

  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  @keyframes slideUp {
    from {
      transform: translateY(40px) scale(0.95);
      opacity: 0;
    }
    to {
      transform: translateY(0) scale(1);
      opacity: 1;
    }
  }

  @media (max-width: 768px) {
    .modal-panel {
      width: 100%;
      max-height: 100vh;
      border-radius: 0;
    }
  }
</style>

