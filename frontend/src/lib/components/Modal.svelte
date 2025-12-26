<script lang="ts">
  import type { Snippet } from 'svelte';
  import { uiStore } from '$lib/stores';
  import Icon from './Icon.svelte';

  interface Props {
    open: boolean;
    title: string;
    onClose: () => void;
    onBack?: () => void;
    children: Snippet;
    actions?: Snippet;
    format?: 'json' | 'txt' | 'auto';
  }

  let { open, title, onClose, onBack, children, actions, format = 'auto' }: Props = $props();

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
        <div class="modal-title-group">
          {#if onBack}
            <button class="btn btn-ghost btn-icon" onclick={onBack} aria-label="Go back">
              <Icon name="back" size={14} />
            </button>
          {/if}
          <h2 class="modal-title mono" id="modalTitle">{title}</h2>
        </div>
        <div class="modal-actions action-bar">
          {#if actions}
            {@render actions()}
          {:else}
            <button class="btn" onclick={handleCopy} aria-label="Copy content">
              <Icon name="copy" size={14} />
              <span>Copy</span>
            </button>
          {/if}
          <button class="btn btn-ghost" onclick={onClose} aria-label="Close modal">
            <Icon name="close" size={14} />
          </button>
        </div>
      </div>
      <div class="modal-body modal-body--mono" class:modal-body--txt={format === 'txt'}>
        {@render children()}
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-title-group {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    min-width: 0;
  }

  .modal-title {
    font-weight: 500;
    font-size: 0.8125rem;
    color: var(--text-primary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Pure white text for TXT files - meant to be read by users */
  .modal-body--txt {
    color: #ffffff;
  }
</style>
