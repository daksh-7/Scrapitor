import { getLogs, getLogContent, getParsedList, getParsedContent, deleteLogs, deleteParsedFiles, renameLog, renameParsedFile } from '$lib/api';
import type { LogItem, ParsedListResponse } from '$lib/api';

// Logs state using Svelte 5 runes
class LogsStore {
  // State
  logs = $state<string[]>([]);
  items = $state<LogItem[]>([]);
  total = $state(0);
  totalAll = $state(0);
  parsedTotal = $state(0);
  loading = $state(false);
  error = $state<string | null>(null);

  // Selection state
  selectedLogs = $state<Set<string>>(new Set());
  selectingLogs = $state(false);
  selectionAction = $state<'write' | 'delete'>('write');

  // Cache for log content
  private jsonCache = new Map<string, string>();
  private parsedListCache = new Map<string, ParsedListResponse>();
  private parsedContentCache = new Map<string, string>();
  
  // O(1) metadata lookup index
  private itemsByName = new Map<string, LogItem>();

  // Computed
  get visibleLogs() {
    return this.logs.slice(0, 100);
  }

  get selectedCount() {
    return this.selectedLogs.size;
  }

  // Actions
  async refresh(silent = false) {
    if (!silent) this.loading = true;
    this.error = null;

    try {
      const data = await getLogs();
      this.logs = data.logs;
      this.items = data.items;
      this.total = data.total;
      this.totalAll = data.total_all;
      this.parsedTotal = data.parsed_total;
      
      // Rebuild O(1) lookup index
      this.itemsByName.clear();
      for (const item of data.items) {
        this.itemsByName.set(item.name, item);
      }
      
      // Prefetch first few logs in background
      this.prefetchLogs(this.logs.slice(0, 5));
    } catch (e) {
      this.error = e instanceof Error ? e.message : 'Failed to load logs';
    } finally {
      this.loading = false;
    }
  }

  // Prefetch log content and parsed TXTs in background (doesn't block UI)
  private prefetchLogs(names: string[]) {
    for (const name of names) {
      // Prefetch JSON content
      if (!this.jsonCache.has(name)) {
        getLogContent(name)
          .then(content => this.jsonCache.set(name, content))
          .catch(() => {});
      }
      
      // Prefetch parsed list and top 2 TXTs
      if (!this.parsedListCache.has(name)) {
        getParsedList(name)
          .then(data => {
            this.parsedListCache.set(name, data);
            // Prefetch top 2 latest parsed TXTs
            const top2 = data.versions.slice(0, 2);
            for (const version of top2) {
              const key = `${name}|${version.file}`;
              if (!this.parsedContentCache.has(key)) {
                getParsedContent(name, version.file)
                  .then(content => this.parsedContentCache.set(key, content))
                  .catch(() => {});
              }
            }
          })
          .catch(() => {});
      }
    }
  }

  async getContent(name: string): Promise<string> {
    if (this.jsonCache.has(name)) {
      return this.jsonCache.get(name)!;
    }
    const content = await getLogContent(name);
    this.jsonCache.set(name, content);
    return content;
  }

  async getParsedVersions(name: string): Promise<ParsedListResponse> {
    if (this.parsedListCache.has(name)) {
      return this.parsedListCache.get(name)!;
    }
    const data = await getParsedList(name);
    this.parsedListCache.set(name, data);
    return data;
  }

  async getParsedText(logName: string, fileName: string): Promise<string> {
    const key = `${logName}|${fileName}`;
    if (this.parsedContentCache.has(key)) {
      return this.parsedContentCache.get(key)!;
    }
    const content = await getParsedContent(logName, fileName);
    this.parsedContentCache.set(key, content);
    return content;
  }

  // Selection methods
  startSelection(action: 'write' | 'delete' = 'write') {
    this.selectingLogs = true;
    this.selectionAction = action;
    this.selectedLogs = new Set();
  }

  cancelSelection() {
    this.selectingLogs = false;
    this.selectedLogs = new Set();
  }

  toggleSelection(name: string) {
    const newSet = new Set(this.selectedLogs);
    if (newSet.has(name)) {
      newSet.delete(name);
    } else {
      newSet.add(name);
    }
    this.selectedLogs = newSet;
  }

  selectAll() {
    this.selectedLogs = new Set(this.visibleLogs);
  }

  deselectAll() {
    this.selectedLogs = new Set();
  }

  toggleSelectAll() {
    const allSelected = this.visibleLogs.every(n => this.selectedLogs.has(n));
    if (allSelected) {
      this.deselectAll();
    } else {
      this.selectAll();
    }
  }

  // Delete operations
  async deleteSelected(): Promise<number> {
    const files = [...this.selectedLogs];
    if (!files.length) return 0;
    
    const result = await deleteLogs(files);
    this.clearCachesFor(files);
    this.cancelSelection();
    await this.refresh();
    return result.deleted;
  }

  async deleteParsed(logName: string, files: string[]): Promise<number> {
    if (!files.length) return 0;
    const result = await deleteParsedFiles(logName, files);
    this.clearCachesFor([logName]);
    return result.deleted;
  }

  // Rename operations
  async rename(name: string, newName: string): Promise<void> {
    await renameLog(name, newName);
    this.clearCachesFor([name]);
    await this.refresh();
  }

  async renameParsed(logName: string, oldFile: string, newFile: string): Promise<void> {
    await renameParsedFile(logName, oldFile, newFile);
    this.clearCachesFor([logName]);
  }

  // Cache management
  clearCachesFor(names: string[]) {
    for (const name of names) {
      this.jsonCache.delete(name);
      this.parsedListCache.delete(name);
      // Clear all parsed content for this log
      for (const key of this.parsedContentCache.keys()) {
        if (key.startsWith(`${name}|`)) {
          this.parsedContentCache.delete(key);
        }
      }
    }
  }

  clearAllCaches() {
    this.jsonCache.clear();
    this.parsedListCache.clear();
    this.parsedContentCache.clear();
  }

  // Get metadata for a log (O(1) lookup)
  getMeta(name: string): LogItem | undefined {
    return this.itemsByName.get(name);
  }
}

export const logsStore = new LogsStore();

