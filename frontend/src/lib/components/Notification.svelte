<script lang="ts">
  import { uiStore } from '$lib/stores';
</script>

{#each uiStore.notifications as notification (notification.id)}
  <div 
    class="notification show"
    class:error={notification.type === 'error'}
    class:warning={notification.type === 'warning'}
    class:info={notification.type === 'info'}
    role="status" 
    aria-live="polite" 
    aria-atomic="true"
  >
    <svg class="notification-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true">
      {#if notification.type === 'error'}
        <path d="M12 8v4m0 4h.01" stroke-width="2" stroke-linecap="round"/>
        <circle cx="12" cy="12" r="10" stroke-width="2"/>
      {:else if notification.type === 'warning'}
        <path d="M12 9v4m0 4h.01" stroke-width="2" stroke-linecap="round"/>
        <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" stroke-width="2"/>
      {:else}
        <path d="M9 11l4 4 8-8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      {/if}
    </svg>
    <span class="notification-message">{notification.message}</span>
  </div>
{/each}

<style>
  .notification {
    position: fixed;
    left: var(--space-lg);
    bottom: var(--space-lg);
    background: var(--surface-secondary);
    border: 1px solid var(--border-interactive);
    border-radius: var(--radius-md);
    padding: var(--space-md) var(--space-lg);
    display: flex;
    gap: var(--space-md);
    align-items: center;
    opacity: 0;
    transform: translateY(20px);
    transition: transform 0.15s ease-out, opacity 0.15s ease-out;
    pointer-events: none;
    z-index: 2000;
  }

  .notification.show {
    opacity: 1;
    transform: translateY(0);
    pointer-events: auto;
  }

  .notification.error {
    border-color: var(--accent-danger);
  }

  .notification.warning {
    border-color: var(--accent-warning);
  }

  .notification.info {
    border-color: var(--border-interactive);
  }

  .notification-icon {
    width: 20px;
    height: 20px;
    color: var(--accent-success);
  }

  .notification.error .notification-icon {
    color: var(--accent-danger);
  }

  .notification.warning .notification-icon {
    color: var(--accent-warning);
  }

  .notification-message {
    font-weight: 500;
    color: var(--text-primary);
    font-size: 0.9375rem;
  }
</style>
