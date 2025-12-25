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
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="modalTitle">
    <button class="modal-backdrop" onclick={onClose} aria-label="Close modal"></button>
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
      <div class="modal-body modal-body--mono">
        {@render children()}
      </div>
    </div>
  </div>
{/if}

<style>
  /* Uses shared modal styles from app.css */
  .modal-title {
    font-family: 'JetBrains Mono', monospace;
  }
</style>
