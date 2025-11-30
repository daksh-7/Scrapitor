/**
 * Message Parser
 *
 * TypeScript port of parser.py
 * Extracts and filters content from JanitorAI messages based on XML-style tags.
 */

import { corsHeaders } from './utils/cors';

export interface ParserConfig {
  mode: 'default' | 'custom';
  includeTags: string[];
  excludeTags: string[];
}

export interface ParsedResult {
  characterName: string;
  content: string;
  tags: string[];
  metadata: {
    scenario?: string;
    firstMessage?: string;
    untaggedContent?: string;
  };
}

const DEFAULT_SKIP_TAGS_FOR_NAME = new Set([
  'system',
  'scenario',
  'example_dialogs',
  'persona',
  'userpersona',
]);

export class MessageParser {
  private config: ParserConfig;

  constructor(config: ParserConfig) {
    this.config = config;
  }

  /**
   * Parse messages array and extract content
   */
  parse(messages: any[]): ParsedResult {
    if (!messages || messages.length === 0) {
      throw new Error('No messages to parse');
    }

    // Find system message
    const systemMsg = messages.find(m => m.role === 'system');
    if (!systemMsg) {
      throw new Error('No system message found');
    }

    const systemContent = this.replaceLiteralNewlines(systemMsg.content || '');

    // Find first character tag
    const firstTag = this.findFirstNonSkippedTag(systemContent, DEFAULT_SKIP_TAGS_FOR_NAME);

    let characterName = 'character';
    let characterContent = '';
    let scenarioContent = '';
    let untaggedContent = '';
    let firstMessage = '';

    // Extract character content
    if (firstTag) {
      const { name, openEnd } = firstTag;
      characterName = name;
      const { content } = this.extractTagContent(systemContent, name, openEnd);
      characterContent = this.filterContent(content, name.toLowerCase());
    }

    // Extract scenario (if exists and not inside character block)
    const scenarioMatch = this.findTag(systemContent, 'scenario');
    if (scenarioMatch) {
      const { content } = this.extractTagContent(systemContent, 'scenario', scenarioMatch.openEnd);
      scenarioContent = this.filterContent(content, 'scenario');
    }

    // Extract untagged content
    untaggedContent = this.extractUntaggedContent(systemContent);

    // Extract first assistant message
    const assistantMsg = messages.find(m => m.role === 'assistant');
    if (assistantMsg && assistantMsg.content) {
      firstMessage = this.replaceLiteralNewlines(assistantMsg.content);
    }

    // Compose final content based on mode
    const finalContent = this.composeOutput({
      characterContent,
      scenarioContent,
      untaggedContent,
      firstMessage,
    });

    return {
      characterName,
      content: finalContent,
      tags: this.extractAllTags(systemContent),
      metadata: {
        scenario: scenarioContent,
        firstMessage,
        untaggedContent,
      },
    };
  }

  /**
   * Replace literal \n with actual newlines
   */
  private replaceLiteralNewlines(text: string): string {
    return text.replace(/\\n/g, '\n');
  }

  /**
   * Find first tag that's not in skip list
   */
  private findFirstNonSkippedTag(
    text: string,
    skipTags: Set<string>
  ): { name: string; openStart: number; openEnd: number } | null {
    const regex = /<\s*([^<>/]+?)\s*>/gi;
    let match;

    while ((match = regex.exec(text)) !== null) {
      const name = match[1].trim();
      if (!skipTags.has(name.toLowerCase())) {
        return {
          name,
          openStart: match.index,
          openEnd: match.index + match[0].length,
        };
      }
    }

    return null;
  }

  /**
   * Find specific tag in text
   */
  private findTag(text: string, tagName: string): { openStart: number; openEnd: number } | null {
    const regex = new RegExp(`<\\s*${this.escapeRegex(tagName)}\\b[^>]*>`, 'i');
    const match = regex.exec(text);
    return match ? { openStart: match.index, openEnd: match.index + match[0].length } : null;
  }

  /**
   * Extract content between opening and closing tags (handles nesting)
   */
  private extractTagContent(
    text: string,
    tagName: string,
    openEnd: number
  ): { content: string; blockEnd: number } {
    const openRegex = new RegExp(`<\\s*${this.escapeRegex(tagName)}\\b[^>]*>`, 'gi');
    const closeRegex = new RegExp(`</\\s*${this.escapeRegex(tagName)}\\s*>`, 'gi');

    let depth = 1;
    let pos = openEnd;
    let blockEnd = text.length;

    while (depth > 0) {
      openRegex.lastIndex = pos;
      closeRegex.lastIndex = pos;

      const nextOpen = openRegex.exec(text);
      const nextClose = closeRegex.exec(text);

      if (!nextClose) {
        // No closing tag found, take rest of text
        break;
      }

      if (nextOpen && nextOpen.index < nextClose.index) {
        // Found nested opening tag
        depth++;
        pos = nextOpen.index + nextOpen[0].length;
      } else {
        // Found closing tag
        depth--;
        if (depth === 0) {
          blockEnd = nextClose.index;
        }
        pos = nextClose.index + nextClose[0].length;
      }
    }

    const content = text.substring(openEnd, blockEnd);
    return { content, blockEnd: pos };
  }

  /**
   * Remove tag blocks from text
   */
  private removeTagBlocks(text: string, tagName: string): string {
    const openRegex = new RegExp(`<\\s*${this.escapeRegex(tagName)}\\b[^>]*>`, 'gi');
    const closeRegex = new RegExp(`</\\s*${this.escapeRegex(tagName)}\\s*>`, 'gi');

    let result = text;
    let pos = 0;

    while (true) {
      openRegex.lastIndex = pos;
      const openMatch = openRegex.exec(result);

      if (!openMatch) break;

      const start = openMatch.index;
      let scanPos = openMatch.index + openMatch[0].length;
      let depth = 1;
      let endPos = result.length;

      while (depth > 0) {
        openRegex.lastIndex = scanPos;
        closeRegex.lastIndex = scanPos;

        const nextOpen = openRegex.exec(result);
        const nextClose = closeRegex.exec(result);

        if (!nextClose) {
          endPos = result.length;
          break;
        }

        if (nextOpen && nextOpen.index < nextClose.index) {
          depth++;
          scanPos = nextOpen.index + nextOpen[0].length;
        } else {
          depth--;
          scanPos = nextClose.index + nextClose[0].length;
          endPos = scanPos;
        }
      }

      result = result.substring(0, start) + result.substring(endPos);
      pos = start;
    }

    return result;
  }

  /**
   * Filter content based on parser configuration
   */
  private filterContent(content: string, tagName: string): string {
    let filtered = content;

    if (this.config.mode === 'custom') {
      const tagLower = tagName.toLowerCase();

      // Include mode
      if (this.config.includeTags.length > 0) {
        if (!this.config.includeTags.includes(tagLower)) {
          return ''; // Tag not included, skip
        }

        // Remove other tags
        const allTags = this.extractAllTags(filtered);
        for (const tag of allTags) {
          if (tag.toLowerCase() !== tagLower && !this.config.includeTags.includes(tag.toLowerCase())) {
            filtered = this.removeTagBlocks(filtered, tag);
          }
        }
      }

      // Exclude mode
      if (this.config.excludeTags.includes(tagLower)) {
        return ''; // Tag excluded
      }

      for (const excludeTag of this.config.excludeTags) {
        filtered = this.removeTagBlocks(filtered, excludeTag);
      }
    }

    return this.replaceLiteralNewlines(filtered).trim();
  }

  /**
   * Extract all tag names from text
   */
  private extractAllTags(text: string): string[] {
    const tags = new Set<string>();
    const regex = /<\s*([^<>/]+?)\s*>/g;
    let match;

    while ((match = regex.exec(text)) !== null) {
      const name = match[1].trim().split(/\s+/)[0]; // Get first word (tag name)
      if (name) {
        tags.add(name);
      }
    }

    return Array.from(tags);
  }

  /**
   * Extract content not within any tags
   */
  private extractUntaggedContent(text: string): string {
    let stripped = text;

    // Remove all tag blocks
    const allTags = this.extractAllTags(text);
    for (const tag of allTags) {
      stripped = this.removeTagBlocks(stripped, tag);
    }

    // Remove remaining tag markers
    stripped = stripped.replace(/<\/?[^<>/]+?[^<>]*>/g, '');

    const result = this.replaceLiteralNewlines(stripped).trim();

    // Apply filters
    if (this.config.mode === 'custom') {
      if (this.config.includeTags.length > 0 && !this.config.includeTags.includes('untagged content')) {
        return '';
      }
      if (this.config.excludeTags.includes('untagged content')) {
        return '';
      }
    }

    return result;
  }

  /**
   * Compose final output based on extracted content
   */
  private composeOutput(parts: {
    characterContent: string;
    scenarioContent: string;
    untaggedContent: string;
    firstMessage: string;
  }): string {
    const lines: string[] = [];

    // Untagged content first
    if (parts.untaggedContent) {
      lines.push(parts.untaggedContent);
    }

    // Character content
    if (parts.characterContent) {
      if (lines.length > 0) lines.push('');
      lines.push(parts.characterContent);
    }

    // Scenario
    if (parts.scenarioContent) {
      if (lines.length > 0) lines.push('');
      lines.push(parts.scenarioContent);
    }

    // First message
    const includeFirstMessage =
      this.config.mode === 'default' ||
      (this.config.mode === 'custom' &&
        (this.config.includeTags.length === 0 || this.config.includeTags.includes('first_message')) &&
        !this.config.excludeTags.includes('first_message'));

    if (parts.firstMessage && includeFirstMessage) {
      if (lines.length > 0) lines.push('');
      lines.push('First Message', '', parts.firstMessage);
    }

    return lines.join('\n').trim() + '\n';
  }

  /**
   * Escape special regex characters
   */
  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}

/**
 * Handle parse endpoint
 */
export async function handleParse(request: Request): Promise<Response> {
  try {
    const body = await request.json();

    if (!body.messages || !Array.isArray(body.messages)) {
      return new Response(
        JSON.stringify({ error: 'Invalid request: messages array required' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders(request),
          },
        }
      );
    }

    const config: ParserConfig = {
      mode: body.parserMode || 'default',
      includeTags: (body.includeTags || []).map((t: string) => t.toLowerCase()),
      excludeTags: (body.excludeTags || []).map((t: string) => t.toLowerCase()),
    };

    const parser = new MessageParser(config);
    const result = parser.parse(body.messages);

    return new Response(JSON.stringify(result), {
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders(request),
      },
    });
  } catch (error) {
    console.error('Parse error:', error);
    return new Response(
      JSON.stringify({
        error: 'Parse error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(request),
        },
      }
    );
  }
}
