<script lang="ts">
  import Section from '$lib/components/Section.svelte';
  import TagChip from '$lib/components/TagChip.svelte';
  import { parserStore, logsStore, uiStore } from '$lib/stores';

  let newTagInput = $state('');
  let tagDetectModalOpen = $state(false);
  let tagDetectSelected = $state<Set<string>>(new Set());
  let writeModalOpen = $state(false);

  async function saveSettings() {
    try {
      await parserStore.save();
      uiStore.notify('Settings saved');
    } catch {
      // Error handled by store
    }
  }

  async function detectLatest() {
    try {
      await parserStore.detectTags();
      uiStore.notify(`Detected ${parserStore.allTags.size} tags`);
    } catch {
      // Error handled by store
    }
  }

  function openTagDetectModal() {
    tagDetectSelected = new Set();
    tagDetectModalOpen = true;
  }

  async function confirmTagDetect() {
    if (tagDetectSelected.size === 0) {
      uiStore.notify('Select at least one log', 'info');
      return;
    }
    try {
      await parserStore.detectTags([...tagDetectSelected]);
      uiStore.notify(`Detected ${parserStore.allTags.size} tags`);
      tagDetectModalOpen = false;
    } catch {
      // Error handled by store
    }
  }

  function toggleTagDetectAll() {
    if (tagDetectSelected.size === logsStore.logs.length) {
      tagDetectSelected = new Set();
    } else {
      tagDetectSelected = new Set(logsStore.logs);
    }
  }

  async function writeLatest() {
    writeModalOpen = false;
    try {
      const result = await parserStore.rewrite('latest');
      uiStore.notify(`Wrote ${result.rewritten} file(s)`);
      await logsStore.refresh();
    } catch {
      // Error handled by store
    }
  }

  function startCustomSelection() {
    writeModalOpen = false;
    logsStore.startSelection('write');
  }

  function addTag() {
    const tag = newTagInput.trim().toLowerCase();
    if (tag) {
      parserStore.addTag(tag);
      newTagInput = '';
      uiStore.notify(`Added tag: ${tag}`);
    }
  }
</script>

<Section id="parser" title="Parser">
  <div class="parameter-grid">
    <div class="parameter-card">
      <div class="parameter-header">
        <span class="parameter-name">Mode</span>
        <span class="parameter-value">{parserStore.mode === 'custom' ? 'Custom' : 'Default'}</span>
      </div>
      <div class="mode-group">
        <label class="mode-pill" class:active={parserStore.mode === 'default'}>
          <input 
            type="radio" 
            name="parser_mode" 
            value="default" 
            checked={parserStore.mode === 'default'}
            onchange={() => parserStore.setMode('default')}
          />
          Default
        </label>
        <label class="mode-pill" class:active={parserStore.mode === 'custom'}>
          <input 
            type="radio" 
            name="parser_mode" 
            value="custom"
            checked={parserStore.mode === 'custom'}
            onchange={() => parserStore.setMode('custom')}
          />
          Custom
        </label>
      </div>
      <div class="metric-label">
        <strong>Default</strong>: no tag filtering; writes character content, Scenario (if present), and First Message. 
        <strong>Custom</strong>: use chips to Include/Exclude; if any tags are Included, only those are written.
      </div>
    </div>

    {#if parserStore.isCustomMode}
      <div class="parameter-card">
        <div class="parameter-header">
          <span class="parameter-name">Tags</span>
          <div class="action-bar">
            <button class="toolbar-btn" onclick={() => parserStore.includeAll()} aria-label="Include all tags">
              <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M9 12l2 2 4-4" stroke-linecap="round" stroke-linejoin="round"/>
                <rect x="3" y="3" width="18" height="18" rx="4"/>
              </svg>
              <span class="btn-label">Include All</span>
            </button>
            <button class="toolbar-btn toolbar-btn--danger" onclick={() => parserStore.excludeAll()} aria-label="Exclude all tags">
              <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M3 6h18" stroke-linecap="round"/>
                <path d="M10 11v6M14 11v6"/>
              </svg>
              <span class="btn-label">Clear All</span>
            </button>
            <button class="toolbar-btn toolbar-btn--accent" onclick={detectLatest} aria-label="Detect tags from latest log">
              <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 8v4l3 2" stroke-linecap="round" stroke-linejoin="round"/>
                <circle cx="12" cy="12" r="9"/>
              </svg>
              <span class="btn-label">Detect Latest</span>
            </button>
            <button class="toolbar-btn toolbar-btn--accent" onclick={openTagDetectModal} aria-label="Detect tags from selected logs">
              <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="4" width="7" height="6" rx="1"/>
                <rect x="14" y="4" width="7" height="6" rx="1"/>
                <rect x="3" y="14" width="7" height="6" rx="1"/>
                <rect x="14" y="14" width="7" height="6" rx="1"/>
              </svg>
              <span class="btn-label">Detect From Logs</span>
            </button>
          </div>
        </div>
        <div class="input-group">
          <input 
            class="copy-input" 
            placeholder="Add tag and press Enter" 
            aria-label="New tag name"
            bind:value={newTagInput}
            onkeypress={(e) => e.key === 'Enter' && addTag()}
          />
          <button class="button" onclick={addTag} aria-label="Add tag">Add</button>
        </div>
        <div class="chips">
          {#each parserStore.sortedTags as tag}
            <TagChip 
              {tag}
              state={parserStore.getTagState(tag)}
              onclick={() => parserStore.cycleTagState(tag)}
            />
          {/each}
        </div>
      </div>
    {/if}
  </div>

  <div class="action-bar">
    <button class="toolbar-btn toolbar-btn--accent" onclick={saveSettings} aria-label="Save parser settings">
      <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M4 4h16v16H4z"/>
        <path d="M7 4v6h10V4"/>
      </svg>
      <span class="btn-label">Save Settings</span>
    </button>
    <button class="toolbar-btn toolbar-btn--accent" onclick={() => writeModalOpen = true} aria-label="Open write options">
      <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 20l9-5-9-5-9 5 9 5z"/>
      </svg>
      <span class="btn-label">Write</span>
    </button>
  </div>
</Section>

<!-- Tag Detect Modal -->
{#if tagDetectModalOpen}
  <div class="modal" role="dialog" aria-modal="true">
    <button class="modal-backdrop" onclick={() => tagDetectModalOpen = false} aria-label="Close modal"></button>
    <div class="modal-panel modal-panel--md">
      <div class="modal-header">
        <div class="modal-title">Detect Tags From Logs</div>
        <div class="modal-actions action-bar">
          <button class="toolbar-btn" onclick={() => tagDetectModalOpen = false}>
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M6 6l12 12M18 6L6 18" stroke-linecap="round"/>
            </svg>
            <span class="btn-label">Close</span>
          </button>
        </div>
      </div>
      <div class="modal-body">
        <div class="detect-list">
          {#each logsStore.logs as log}
            <label class="detect-item">
              <input 
                type="checkbox" 
                checked={tagDetectSelected.has(log)}
                onchange={() => {
                  const newSet = new Set(tagDetectSelected);
                  if (newSet.has(log)) {
                    newSet.delete(log);
                  } else {
                    newSet.add(log);
                  }
                  tagDetectSelected = newSet;
                }}
              />
              <span>{log}</span>
            </label>
          {/each}
        </div>
        <div class="action-bar" style="margin-top: 0.75rem;">
          <button class="toolbar-btn toolbar-btn--accent" onclick={confirmTagDetect}>
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 8v4l3 2" stroke-linecap="round" stroke-linejoin="round"/>
              <circle cx="12" cy="12" r="9"/>
            </svg>
            <span class="btn-label">Detect</span>
          </button>
          <button class="toolbar-btn" onclick={toggleTagDetectAll}>
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M4 7h16M4 12h16M4 17h16" stroke-linecap="round"/>
            </svg>
            <span class="btn-label">Select All</span>
          </button>
          <button class="toolbar-btn toolbar-btn--danger" onclick={() => tagDetectSelected = new Set()}>
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M3 6h18" stroke-linecap="round"/>
              <path d="M10 11v6M14 11v6"/>
            </svg>
            <span class="btn-label">Clear</span>
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<!-- Write Options Modal -->
{#if writeModalOpen}
  <div class="modal" role="dialog" aria-modal="true">
    <button class="modal-backdrop" onclick={() => writeModalOpen = false} aria-label="Close modal"></button>
    <div class="modal-panel modal-panel--sm">
      <div class="modal-header">
        <div class="modal-title">Write Options</div>
        <div class="modal-actions action-bar">
          <button class="toolbar-btn" onclick={() => writeModalOpen = false}>
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M6 6l12 12M18 6L6 18" stroke-linecap="round"/>
            </svg>
            <span class="btn-label">Close</span>
          </button>
        </div>
      </div>
      <div class="modal-body">
        <div class="write-options">
          <button class="button" onclick={writeLatest}>Write Latest</button>
          <button class="button button-secondary" onclick={startCustomSelection}>Custom Selection…</button>
        </div>
        <p class="write-hint">
          Choose Latest to write the most recent JSON, or Custom to select files from Activity.
        </p>
      </div>
    </div>
  </div>
{/if}

<style>
  .mode-group {
    display: flex;
    gap: var(--space-sm);
  }

  .mode-pill {
    display: inline-flex;
    align-items: center;
    gap: var(--space-sm);
    padding: var(--space-sm) var(--space-md);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-full);
    background: rgba(255, 255, 255, 0.02);
    cursor: pointer;
    transition: background-color 0.15s, border-color 0.15s, color 0.15s;
    font-weight: 500;
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  .mode-pill input[type="radio"] {
    display: none;
  }

  .mode-pill:hover {
    border-color: var(--border-interactive);
    background: rgba(255, 255, 255, 0.04);
    color: var(--text-primary);
  }

  .mode-pill.active {
    background: linear-gradient(135deg, var(--accent-primary) 0%, var(--accent-secondary) 100%);
    border-color: transparent;
    color: var(--bg-primary);
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-sm);
    margin-top: 0.75rem;
  }

  /* Modal size variants (uses shared modal styles from app.css) */
  .modal-panel--sm {
    width: min(400px, 90vw);
  }

  .modal-panel--md {
    width: min(600px, 90vw);
  }

  .detect-list {
    max-height: 50vh;
    overflow-y: auto;
  }

  .detect-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.25rem 0;
    border-bottom: 1px solid var(--border-subtle);
    cursor: pointer;
  }

  .detect-item:last-child {
    border-bottom: 0;
  }

  .write-options {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .write-hint {
    margin-top: 0.75rem;
    color: var(--text-tertiary);
  }
</style>
