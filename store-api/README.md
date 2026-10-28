# ItamarOS Store API (early prototype)

Node.js server with no external dependencies.

- `GET /health`: health check
- `GET /api/apps`: curated catalog of official developer sites
- `GET /api/apps/:id`: individual app
- `POST /api/suggestions`: returns 501 until a secure moderation database is available

**Not yet implemented:** EXE download, binary scanning, file hosting, age ratings, persistent submissions, and direct installer delivery. No unknown binaries are executed or downloaded.

Render root-directory setting should be `store-api`; build command `npm install`; start command `npm start`.
