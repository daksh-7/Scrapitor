<script lang="ts">
  import { uiStore } from '$lib/stores';
  import Icon from './Icon.svelte';
</script>

<div class="notification-container" aria-live="polite" aria-atomic="true">
  {#each uiStore.notifications as notification (notification.id)}
    <div 
      class="notification"
      class:error={notification.type === 'error'}
      class:warning={notification.type === 'warning'}
      class:info={notification.type === 'info'}
      role="status"
    >
      <div class="notification-icon">
        {#if notification.type === 'error'}
          <Icon name="error" size={16} />
        {:else if notification.type === 'warning'}
          <Icon name="warning" size={16} />
        {:else if notification.type === 'info'}
          <Icon name="info" size={16} />
        {:else}
          <Icon name="check" size={16} />
        {/if}
      </div>
      <span class="notification-message">{notification.message}</span>
      <button 
        class="notification-dismiss"
        onclick={() => uiStore.dismissNotification(notification.id)}
        aria-label="Dismiss"
      >
        <Icon name="close" size={12} />
      </button>
    </div>
  {/each}
</div>

<style>
  .notification-container {
    position: fixed;
    bottom: var(--space-lg);
    right: var(--space-lg);
    display: flex;
    flex-direction: column;
    gap: var(--space-sm);
    z-index: 2000;
    pointer-events: none;
  }

  .notification {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    padding: var(--space-sm) var(--space-md);
    background: var(--bg-elevated);
    border: 1px solid var(--success-border);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-lg);
    pointer-events: auto;
    animation: slideInRight var(--duration-normal) var(--ease-out);
    max-width: 360px;
  }

  .notification.error {
    border-color: var(--danger-border);
  }

  .notification.warning {
    border-color: rgba(234, 179, 8, 0.3);
  }

  .notification.info {
    border-color: var(--accent-border);
  }

  .notification-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--success);
    flex-shrink: 0;
  }

  .notification.error .notification-icon {
    color: var(--danger);
  }

  .notification.warning .notification-icon {
    color: var(--warning);
  }

  .notification.info .notification-icon {
    color: var(--accent);
  }

  .notification-message {
    flex: 1;
    font-weight: 500;
    font-size: 0.8125rem;
    color: var(--text-primary);
    line-height: 1.4;
  }

  .notification-dismiss {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border: none;
    background: transparent;
    color: var(--text-muted);
    cursor: pointer;
    border-radius: var(--radius-sm);
    flex-shrink: 0;
    transition: color var(--duration-fast), background-color var(--duration-fast);
  }

  .notification-dismiss:hover {
    color: var(--text-primary);
    background: var(--bg-hover);
  }

  @media (max-width: 640px) {
    .notification-container {
      left: var(--space-md);
      right: var(--space-md);
      bottom: var(--space-md);
    }

    .notification {
      max-width: none;
    }
  }
</style>
