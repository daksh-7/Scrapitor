/**
 * Scrapitor Cloudflare Workers API
 *
 * Main entry point for the API that handles:
 * - OpenRouter proxy requests
 * - Message parsing
 * - Character card generation
 */

import { handleProxy } from './proxy';
import { handleParse } from './parser';
import { handleCharacterCard } from './character-card';
import { handleCORS, corsHeaders } from './utils/cors';

export interface Env {
  // Uncomment when using D1/R2
  // DB: D1Database;
  // STORAGE: R2Bucket;

  // Environment variables
  ENVIRONMENT?: string;
  OPENROUTER_URL?: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return handleCORS(request);
    }

    try {
      // Health check
      if (url.pathname === '/health' || url.pathname === '/api/health') {
        return new Response(
          JSON.stringify({
            status: 'healthy',
            version: '2.0-workers',
            timestamp: new Date().toISOString(),
          }),
          {
            headers: {
              'Content-Type': 'application/json',
              ...corsHeaders(request),
            },
          }
        );
      }

      // OpenRouter proxy endpoint
      if (url.pathname === '/api/proxy' || url.pathname === '/openrouter-cc' || url.pathname === '/chat/completions') {
        return await handleProxy(request, env);
      }

      // Parse messages endpoint
      if (url.pathname === '/api/parse') {
        return await handleParse(request);
      }

      // Character card generation endpoint
      if (url.pathname === '/api/create-card') {
        return await handleCharacterCard(request);
      }

      // Models endpoint (for compatibility)
      if (url.pathname === '/models') {
        return new Response(
          JSON.stringify({
            object: 'list',
            data: [
              {
                id: 'openrouter-proxy',
                object: 'model',
                created: 0,
                owned_by: 'scrapitor-workers',
              },
            ],
          }),
          {
            headers: {
              'Content-Type': 'application/json',
              ...corsHeaders(request),
            },
          }
        );
      }

      // Not found
      return new Response('Not Found', {
        status: 404,
        headers: corsHeaders(request),
      });
    } catch (error) {
      console.error('Error handling request:', error);
      return new Response(
        JSON.stringify({
          error: 'Internal Server Error',
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
  },
};
