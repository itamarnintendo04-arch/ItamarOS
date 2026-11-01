# ItamarOS Store API and ChatGPT MCP endpoint

This Render service serves the original Store API and a read-only MCP server from the **same** process.

- `GET /health` — store API health
- `GET /api/apps` — curated public catalog
- `GET /api/apps/:id` — details for a catalog entry
- `POST /api/suggestions` — 501 until a reviewed submission backend exists
- `POST /mcp` — Model Context Protocol Streamable HTTP endpoint (also handles other protocol methods)

## Existing Render service

Use the existing `itamaros-store-api` web service. Preserve:
- Build command: `cd store-api && npm install`
- Start command: `cd store-api && npm start`
- Runtime: Node.js 22+

The MCP URL is `https://itamaros-store-api.onrender.com/mcp`.
Use ChatGPT web > Plugins > + > Add custom MCP server if your account/workspace permits.
The exposed tools are `itamaros_about`, `itamaros_latest_releases`, and `itamaros_builds`. They access only **public** repository data; do not expose secrets, accounts, devices or write functions.

The /mcp endpoint requires an MCP client. Opening it in an ordinary web browser will not show a plugin page. Connecting/installation is a separate user-controlled ChatGPT action.

**Limits:** These are prototypes. The endpoint is unauthenticated and intended exclusively for harmless, public, read-only tools. Protect or add an authenticated API before introducing private or write tools.
