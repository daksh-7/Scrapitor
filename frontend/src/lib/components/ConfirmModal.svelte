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
</style>
