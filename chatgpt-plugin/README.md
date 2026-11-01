# ItamarOS for ChatGPT · Custom MCP Plugin

**Status:** code created, **not deployed or installed**. This is not an official OpenAI plugin.

This folder defines a **read-only** MCP Streamable HTTP server. It uses the current v2 MCP TypeScript server and Node adapter (Node.js 22+). No Supabase keys, user accounts, chats, Apple signing assets or device data are sent to it.

## Tools

| Tool | What it does |
| --- | --- |
| `itamaros_about` | Public project information, download links and accuracy disclaimers |
| `itamaros_latest_releases` | Lists verified public GitHub release tags and attached assets |
| `itamaros_builds` | Checks public GitHub Actions conclusions and build pages |

## Deploy your own server

1. From this folder run `npm install` then `npm start` on a Node 22+ HTTPS-capable host. Default `PORT=3000`; your host should terminate HTTPS.
2. Open `https://YOUR-SERVER.example/health`; expect `{"status":"ok","service":"itamaros-readonly-mcp"}`.
3. Test the Streamable HTTP endpoint `https://YOUR-SERVER.example/mcp` with an MCP client. It requires an MCP handshake, **not** an ordinary browser navigation.
4. In ChatGPT **on the web**, open Plugins → + → Add custom MCP server, give it the name **ItamarOS**, and enter your server's `https://.../mcp` endpoint. You must approve the connection yourself. Eligibility and controls depend on plan/workspace policy.
5. Try asking: “Check ItamarOS latest public releases.” It should return only the public GitHub data.

Never enter private credentials into the plugin. The current tools deliberately do not expose chat history or control the OS. If future write features are added, use a proper authorization flow and confirmation prompts.

The repository contains the source only. No ChatGPT plugin installation, remote deployment, or app directory submission is implied.

Official reference: https://developers.openai.com/api/docs/guides/custom-mcp-server
