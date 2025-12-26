<script lang="ts">
  interface Props {
    name: IconName;
    size?: number;
    class?: string;
  }

  export type IconName = 
    | 'home'
    | 'clock'
    | 'refresh'
    | 'copy'
    | 'close'
    | 'back'
    | 'check'
    | 'checkSquare'
    | 'trash'
    | 'save'
    | 'write'
    | 'detect'
    | 'grid'
    | 'activity'
    | 'layers'
    | 'server'
    | 'externalLink'
    | 'warning'
    | 'info'
    | 'error'
    | 'edit'
    | 'download'
    | 'export';

  let { name, size = 16, class: className = '' }: Props = $props();
</script>

<svg 
  class="icon {className}"
  width={size} 
  height={size} 
  viewBox="0 0 24 24" 
  fill="none" 
  stroke="currentColor" 
  stroke-width="2"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>
  {#if name === 'home'}
    <path d="M3 12l9-9 9 9"/>
    <path d="M9 21V9h6v12"/>
  {:else if name === 'clock'}
    <circle cx="12" cy="12" r="10"/>
    <path d="M12 6v6l4 2"/>
  {:else if name === 'refresh'}
    <path d="M21 12a9 9 0 10-3.2 6.8"/>
    <path d="M21 12v6h-6"/>
  {:else if name === 'copy'}
    <rect x="9" y="9" width="13" height="13" rx="2"/>
    <rect x="2" y="2" width="13" height="13" rx="2"/>
  {:else if name === 'close'}
    <path d="M6 6l12 12M18 6L6 18"/>
  {:else if name === 'back'}
    <path d="M12 19l-7-7 7-7"/>
  {:else if name === 'check'}
    <path d="M5 12l5 5 9-9"/>
  {:else if name === 'checkSquare'}
    <path d="M9 12l2 2 4-4"/>
    <rect x="3" y="3" width="18" height="18" rx="4"/>
  {:else if name === 'trash'}
    <path d="M3 6h18"/>
    <path d="M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6"/>
    <path d="M10 11v6M14 11v6"/>
  {:else if name === 'save'}
    <path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/>
    <path d="M17 21v-8H7v8"/>
    <path d="M7 3v5h8"/>
  {:else if name === 'write'}
    <path d="M12 20l9-5-9-5-9 5 9 5z"/>
    <path d="M3 10l9-5 9 5"/>
  {:else if name === 'detect'}
    <circle cx="11" cy="11" r="8"/>
    <path d="M21 21l-4.35-4.35"/>
  {:else if name === 'grid'}
    <rect x="3" y="3" width="7" height="7" rx="1"/>
    <rect x="14" y="3" width="7" height="7" rx="1"/>
    <rect x="3" y="14" width="7" height="7" rx="1"/>
    <rect x="14" y="14" width="7" height="7" rx="1"/>
  {:else if name === 'activity'}
    <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
  {:else if name === 'layers'}
    <polygon points="12 2 2 7 12 12 22 7 12 2"/>
    <polyline points="2 17 12 22 22 17"/>
    <polyline points="2 12 12 17 22 12"/>
  {:else if name === 'server'}
    <rect x="2" y="2" width="20" height="8" rx="2"/>
    <rect x="2" y="14" width="20" height="8" rx="2"/>
    <path d="M6 6h.01M6 18h.01"/>
  {:else if name === 'externalLink'}
    <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/>
    <polyline points="15 3 21 3 21 9"/>
    <line x1="10" y1="14" x2="21" y2="3"/>
  {:else if name === 'warning'}
    <path d="M12 9v4m0 4h.01"/>
    <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
  {:else if name === 'info'}
    <circle cx="12" cy="12" r="10"/>
    <path d="M12 16v-4m0-4h.01"/>
  {:else if name === 'error'}
    <circle cx="12" cy="12" r="10"/>
    <path d="M12 8v4m0 4h.01"/>
  {:else if name === 'edit'}
    <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
    <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
  {:else if name === 'download'}
    <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
    <polyline points="7 10 12 15 17 10"/>
    <line x1="12" y1="15" x2="12" y2="3"/>
  {:else if name === 'export'}
    <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
    <polyline points="17 8 12 3 7 8"/>
    <line x1="12" y1="3" x2="12" y2="15"/>
  {/if}
</svg>

<style>
  .icon {
    flex-shrink: 0;
  }
</style>

