<script lang="ts">
  interface Props {
    open: boolean;
    title?: string;
    message: string;
    confirmText?: string;
    cancelText?: string;
    danger?: boolean;
    onConfirm: () => void;
    onCancel: () => void;
  }

  let { 
    open, 
    title = 'Confirm', 
    message, 
    confirmText = 'Confirm', 
    cancelText = 'Cancel',
    danger = true,
    onConfirm, 
    onCancel 
  }: Props = $props();

  function handleKeydown(e: KeyboardEvent) {
    if (!open) return;
    if (e.key === 'Escape') onCancel();
    if (e.key === 'Enter') onConfirm();
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="confirmTitle">
    <div class="modal-backdrop" onclick={onCancel} aria-hidden="true"></div>
    <div class="modal-panel modal-panel--sm">
      <div class="modal-header">
        <div class="modal-title" id="confirmTitle">{title}</div>
        <div class="modal-actions action-bar">
          <button class="toolbar-btn" onclick={onCancel} aria-label="Cancel">
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path d="M6 6l12 12M18 6L6 18" stroke-linecap="round"/>
            </svg>
            <span class="btn-label">{cancelText}</span>
          </button>
          <button 
            class="toolbar-btn" 
            class:toolbar-btn--danger={danger}
            class:toolbar-btn--accent={!danger}
            onclick={onConfirm} 
            aria-label="Confirm"
          >
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              {#if danger}
                <path d="M3 6h18" stroke-linecap="round"/>
                <path d="M10 11v6M14 11v6"/>
              {:else}
                <path d="M9 11l4 4 8-8" stroke-linecap="round" stroke-linejoin="round"/>
              {/if}
            </svg>
            <span class="btn-label">{confirmText}</span>
          </button>
        </div>
      </div>
      <div class="modal-body">
        {message}
      </div>
    </div>
  </div>
{/if}

<style>
  /* Uses shared modal styles from app.css */
  .modal-panel--sm {
    width: min(500px, 90vw);
  }
</style>
