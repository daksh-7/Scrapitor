# Scrapitor Workers API

Cloudflare Workers-based API for Scrapitor, providing:
- OpenRouter API proxy
- Message parsing (TypeScript port of parser.py)
- Character Card V2 generation

## Development

```bash
# Install dependencies
npm install

# Run locally
npm run dev

# Deploy to Cloudflare
npm run deploy
```

## Configuration

### Environment Variables

Set in `wrangler.toml` or via Cloudflare dashboard:

- `ENVIRONMENT`: `production` or `staging`
- `OPENROUTER_URL`: (optional) Custom OpenRouter endpoint

### Wrangler Setup

1. Install Wrangler CLI: `npm install -g wrangler`
2. Login: `wrangler login`
3. Deploy: `wrangler deploy`

## API Endpoints

### `/api/proxy` or `/openrouter-cc`
OpenRouter proxy endpoint. Forwards chat completion requests.

**Request:**
```json
POST /api/proxy
Authorization: Bearer YOUR_OPENROUTER_KEY

{
  "model": "mistralai/mistral-small",
  "messages": [...],
  "stream": false
}
```

### `/api/parse`
Parse messages and extract character content.

**Request:**
```json
POST /api/parse

{
  "messages": [...],
  "parserMode": "custom",
  "includeTags": ["character", "scenario"],
  "excludeTags": []
}
```

**Response:**
```json
{
  "characterName": "Miku",
  "content": "...",
  "tags": ["character", "scenario"],
  "metadata": {
    "scenario": "...",
    "firstMessage": "..."
  }
}
```

### `/api/create-card`
Generate Character Card V2 data.

**Request:**
```json
POST /api/create-card

{
  "characterName": "Miku",
  "content": "Character description...",
  "scenario": "...",
  "firstMessage": "...",
  "tags": ["anime", "vocaloid"]
}
```

**Response:**
```json
{
  "spec": "chara_card_v2",
  "spec_version": "2.0",
  "data": {
    "name": "Miku",
    "description": "...",
    ...
  }
}
```

## Testing

```bash
# Run tests
npm test

# Test locally
curl http://localhost:8787/health
```

## Deployment

### Automatic (GitHub Actions)

Push to `main` branch to auto-deploy via GitHub Actions.

### Manual

```bash
npm run deploy
```

## License

MIT
