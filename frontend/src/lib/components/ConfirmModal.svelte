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
    <div class="modal-panel">
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
    width: min(500px, 90vw);
    background: linear-gradient(135deg, 
      rgba(26, 29, 33, 0.95) 0%, 
      rgba(18, 20, 23, 0.98) 100%);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-xl);
    box-shadow: 
      var(--shadow-2xl),
      0 0 80px rgba(0, 0, 0, 0.5),
      0 0 40px rgba(0, 212, 255, 0.1);
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
  }

  .modal-actions {
    display: flex;
    gap: var(--space-sm);
  }

  .modal-body {
    padding: var(--space-lg);
    color: var(--text-secondary);
    font-size: 0.9375rem;
    line-height: 1.6;
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
    transition: all 0.2s var(--ease-smooth);
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

  .toolbar-btn--accent {
    border-color: var(--border-interactive);
    color: var(--accent-primary);
  }

  .toolbar-btn--accent:hover {
    background: rgba(0, 212, 255, 0.06);
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
</style>

