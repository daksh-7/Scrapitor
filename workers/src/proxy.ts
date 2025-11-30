/**
 * OpenRouter API Proxy
 *
 * Forwards requests to OpenRouter with proper authentication
 * and CORS headers.
 */

import { Env } from './index';
import { corsHeaders } from './utils/cors';

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const CONNECT_TIMEOUT = 5000;
const READ_TIMEOUT = 300000;

export async function handleProxy(request: Request, env: Env): Promise<Response> {
  // Only allow POST requests
  if (request.method !== 'POST' && request.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(request),
        },
      }
    );
  }

  // Handle GET request (health check)
  if (request.method === 'GET') {
    return new Response(
      JSON.stringify({
        status: 'alive',
        message: 'Proxy alive - POST your /chat/completions here',
        version: '2.0-workers',
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(request),
        },
      }
    );
  }

  try {
    // Parse request body
    const payload = await request.json();

    // Validate payload
    if (!payload || typeof payload !== 'object') {
      return new Response(
        JSON.stringify({ error: 'Invalid request body' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders(request),
          },
        }
      );
    }

    // Get authorization header
    const authorization = request.headers.get('Authorization');
    if (!authorization) {
      return new Response(
        JSON.stringify({
          error: 'Missing Authorization header. Provide your OpenRouter API key as an Authorization bearer token.',
        }),
        {
          status: 401,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders(request),
          },
        }
      );
    }

    // Prepare headers for OpenRouter
    const upstreamHeaders = new Headers({
      'Content-Type': 'application/json',
      'Authorization': authorization,
      'HTTP-Referer': 'https://github.com/scrapitor/scrapitor',
      'X-Title': 'Scrapitor-Workers',
    });

    // Forward to OpenRouter
    const upstreamUrl = env.OPENROUTER_URL || OPENROUTER_URL;
    const upstreamResponse = await fetch(upstreamUrl, {
      method: 'POST',
      headers: upstreamHeaders,
      body: JSON.stringify(payload),
    });

    // Handle streaming response
    if (payload.stream) {
      return new Response(upstreamResponse.body, {
        status: upstreamResponse.status,
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          ...corsHeaders(request),
        },
      });
    }

    // Handle regular response
    const data = await upstreamResponse.json();

    return new Response(JSON.stringify(data), {
      status: upstreamResponse.status,
      headers: {
        'Content-Type': 'application/json',
        ...corsHeaders(request),
      },
    });
  } catch (error) {
    console.error('Proxy error:', error);
    return new Response(
      JSON.stringify({
        error: 'Proxy error',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 502,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(request),
        },
      }
    );
  }
}
