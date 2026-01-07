<script lang="ts">
  import Icon from './Icon.svelte';

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
        <h2 class="modal-title" id="confirmTitle">{title}</h2>
      </div>
      <div class="modal-body">
        <p class="confirm-message">{message}</p>
        <div class="confirm-actions">
          <button class="btn" onclick={onCancel}>
            {cancelText}
          </button>
          <button 
            class="btn"
            class:btn-danger={danger}
            class:btn-primary={!danger}
            onclick={onConfirm}
          >
            {#if danger}
              <Icon name="trash" size={14} />
            {:else}
              <Icon name="check" size={14} />
            {/if}
            {confirmText}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  .confirm-message {
    color: var(--text-secondary);
    line-height: 1.5;
    margin-bottom: var(--space-lg);
  }

  .confirm-actions {
    display: flex;
    gap: var(--space-sm);
    justify-content: flex-end;
  }

  /* Mobile breakpoint */
  @media (max-width: 767px) {
    /* Keep confirm modal centered on mobile instead of bottom-aligned */
    :global(.modal:has(.modal-panel--sm)) {
      align-items: center;
      padding: var(--space-lg);
      /* Shift content down to account for browser URL bar */
      padding-top: 80px;
    }

    :global(.modal-panel--sm) {
      max-height: calc(100% - 100px);
      margin-top: 0;
      border-radius: var(--radius-xl);
      animation: fadeInUp var(--duration-normal) var(--ease-out);
    }

    .confirm-message {
      font-size: 0.9375rem;
      text-align: center;
      margin-bottom: var(--space-xl);
    }

    .confirm-actions {
      flex-direction: column-reverse;
      gap: var(--space-sm);
    }

    .confirm-actions .btn {
      width: 100%;
      min-height: 48px;
      justify-content: center;
      font-size: 0.9375rem;
    }
  }
</style>
