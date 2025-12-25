import { getParserSettings, saveParserSettings, getParserTags, rewriteParsed } from '$lib/api';

class ParserStore {
  // Settings
  mode = $state<'default' | 'custom'>('default');
  includeTags = $state<Set<string>>(new Set());
  excludeTags = $state<Set<string>>(new Set());
  allTags = $state<Set<string>>(new Set());
  
  // Tag detection metadata
  tagToFiles = $state<Record<string, string[]>>({});
  detectedFiles = $state<string[]>([]);
  
  // Loading state
  loading = $state(false);
  error = $state<string | null>(null);

  // Computed
  get isCustomMode() {
    return this.mode === 'custom';
  }

  get sortedTags(): string[] {
    return [...this.allTags].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
  }

  getTagState(tag: string): 'include' | 'exclude' | 'neutral' {
    const key = tag.toLowerCase();
    if (this.includeTags.has(key)) return 'include';
    if (this.excludeTags.has(key)) return 'exclude';
    return 'neutral';
  }

  // Actions
  async loadSettings() {
    this.loading = true;
    this.error = null;

    try {
      const settings = await getParserSettings();
      this.mode = settings.mode;
      this.excludeTags = new Set((settings.exclude_tags || []).map(t => t.toLowerCase()));
      this.includeTags = new Set(); // Include tags are ephemeral
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'Failed to load settings';
    } finally {
      this.loading = false;
    }
  }

  async save() {
    this.loading = true;
    this.error = null;

    try {
      await saveParserSettings({
        mode: this.mode,
        exclude_tags: [...this.excludeTags],
      });
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'Failed to save settings';
      throw e;
    } finally {
      this.loading = false;
    }
  }

  setMode(mode: 'default' | 'custom') {
    this.mode = mode;
  }

  // Tag state cycling: neutral → include → exclude → neutral
  cycleTagState(tag: string) {
    const key = tag.toLowerCase();
    
    if (this.includeTags.has(key)) {
      // include → exclude
      const newInclude = new Set(this.includeTags);
      newInclude.delete(key);
      this.includeTags = newInclude;
      
      const newExclude = new Set(this.excludeTags);
      newExclude.add(key);
      this.excludeTags = newExclude;
    } else if (this.excludeTags.has(key)) {
      // exclude → neutral (which acts as include for display purposes)
      const newExclude = new Set(this.excludeTags);
      newExclude.delete(key);
      this.excludeTags = newExclude;
      
      const newInclude = new Set(this.includeTags);
      newInclude.add(key);
      this.includeTags = newInclude;
    } else {
      // neutral → include
      const newInclude = new Set(this.includeTags);
      newInclude.add(key);
      this.includeTags = newInclude;
    }
  }

  includeAll() {
    this.includeTags = new Set([...this.allTags].map(t => t.toLowerCase()));
    this.excludeTags = new Set();
  }

  excludeAll() {
    this.excludeTags = new Set([...this.allTags].map(t => t.toLowerCase()));
    this.includeTags = new Set();
  }

  // Tag detection
  async detectTags(files?: string[]) {
    this.loading = true;
    this.error = null;

    try {
      const data = await getParserTags(files);
      
      // Update all tags with detected ones + first_message
      const tags = new Set(data.tags.map(t => t.toLowerCase()));
      tags.add('first_message');
      this.allTags = tags;
      
      // Store file mapping
      this.tagToFiles = Object.fromEntries(
        Object.entries(data.by_tag).map(([tag, files]) => [
          tag.toLowerCase(),
          files.map(f => f.toLowerCase())
        ])
      );
      
      this.detectedFiles = data.files.map(n => n.toLowerCase());
      
      return data;
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'Failed to detect tags';
      throw e;
    } finally {
      this.loading = false;
    }
  }

  // Get files that have a specific tag
  getFilesForTag(tag: string): string[] {
    return this.tagToFiles[tag.toLowerCase()] || [];
  }

  // Rewrite operations
  async rewrite(mode: 'all' | 'latest' | 'custom', files?: string[]) {
    this.loading = true;
    this.error = null;

    try {
      const result = await rewriteParsed({
        mode,
        files,
        parser_mode: this.mode,
        include_tags: [...this.includeTags],
        exclude_tags: [...this.excludeTags],
      });
      return result;
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'Rewrite failed';
      throw e;
    } finally {
      this.loading = false;
    }
  }

  addTag(tag: string) {
    const key = tag.toLowerCase().trim();
    if (!key) return;
    
    const newTags = new Set(this.allTags);
    newTags.add(key);
    this.allTags = newTags;
    
    // New tags start as excluded
    const newExclude = new Set(this.excludeTags);
    newExclude.add(key);
    this.excludeTags = newExclude;
  }
}

export const parserStore = new ParserStore();

