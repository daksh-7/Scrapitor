/**
 * CORS utilities for handling cross-origin requests
 */

const ALLOWED_ORIGINS = ['*']; // Configure this based on your needs

export function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin') || '*';

  // Allow all origins in development, or check against whitelist
  const allowedOrigin = ALLOWED_ORIGINS.includes('*')
    ? '*'
    : ALLOWED_ORIGINS.includes(origin)
      ? origin
      : ALLOWED_ORIGINS[0];

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

export function handleCORS(request: Request): Response {
  return new Response(null, {
    status: 204,
    headers: corsHeaders(request),
  });
}
