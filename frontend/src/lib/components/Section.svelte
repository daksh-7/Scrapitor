<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    id: string;
    title: string;
    children: Snippet;
  }

  let { id, title, children }: Props = $props();
</script>

<section {id} class="section" aria-labelledby="{id}-title">
  <h2 id="{id}-title" class="section-header">{title}</h2>
  {@render children()}
</section>

<style>
  .section {
    background: linear-gradient(135deg, 
      rgba(22, 24, 28, 0.6) 0%, 
      rgba(16, 18, 21, 0.8) 100%);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-xl);
    padding: var(--space-xl);
    margin-bottom: var(--space-lg);
    position: relative;
    overflow: hidden;
    box-shadow: 
      var(--shadow-xl),
      inset 0 1px 0 rgba(255, 255, 255, 0.05);
    transition: transform 0.3s var(--ease-smooth), box-shadow 0.3s var(--ease-smooth), border-color 0.3s var(--ease-smooth);
    scroll-margin-top: 84px;
  }

  .section::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 1px;
    background: linear-gradient(90deg, 
      transparent, 
      rgba(0, 212, 255, 0.3), 
      transparent);
    animation: shimmer 3s infinite;
  }

  @keyframes shimmer {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(100%); }
  }

  .section:hover {
    transform: translateY(-2px);
    box-shadow: 
      var(--shadow-2xl),
      0 0 40px rgba(0, 212, 255, 0.05);
  }

  .section-header {
    font-size: 1.5rem;
    font-weight: 700;
    margin-bottom: var(--space-xl);
    background: linear-gradient(135deg, 
      var(--accent-primary) 0%, 
      var(--accent-secondary) 100%);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    display: flex;
    align-items: center;
    gap: var(--space-md);
    letter-spacing: -0.03em;
  }

  :global(body.compact) .section {
    padding: var(--space-lg);
    margin-bottom: var(--space-md);
  }
</style>

