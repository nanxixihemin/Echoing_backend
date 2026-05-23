# Echoing Backend

Echoing backend is intentionally small: Python standard library, SQLite, no web framework dependency.

It provides:

- ModelScope chat-completions proxy
- Shared forest persistence
- Admin login and bearer-token auth
- Admin panel
- Leaf moderation and deletion
- AI request history
- App user profile upsert
- Account-scoped chat sessions and memory context
- SQLite schema migrations

## Configure

Create `backend/.env` from `.env.example`.

```env
MODELSCOPE_API_KEY=replace_with_modelscope_api_key
MODELSCOPE_API_BASE=https://api-inference.modelscope.cn/v1
MODELSCOPE_MODEL=deepseek-ai/DeepSeek-V4-Flash
HOST=0.0.0.0
PORT=8111
ECHOING_DB_PATH=./data/echoing.db
ADMIN_USERNAME=admin
ADMIN_PASSWORD=replace_with_strong_admin_password
AUTH_TOKEN_TTL_HOURS=24
MODERATION_BLOCK_KEYWORDS=
```

Do not commit `backend/.env`. Change `ADMIN_PASSWORD` before deployment.

The first admin user is created automatically on startup when the `admin_users` table is empty.

## Run

```powershell
cd backend
python server.py
```

Health check:

```text
http://127.0.0.1:8111/health
```

Admin panel:

```text
http://127.0.0.1:8111/admin
```

## Public APIs

List shared leaves:

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:8111/api/leaves
```

Create a leaf:

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:8111/api/leaves -Method POST -ContentType 'application/json' -Headers @{"X-Account-Key"="email:test@example.com"} -Body '{"content":"hello","nickname":"anonymous","accountKey":"email:test@example.com","ownerNickname":"Xixi"}'
```

Like a leaf:

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:8111/api/leaves/<leaf_id>/like -Method POST
```

AI proxy:

```text
POST /v1/chat/completions
```

The backend always uses `MODELSCOPE_MODEL` from `.env`; the app cannot override the model.

App user upsert:

```text
POST /api/app-users/upsert
```

Chat session list/save:

```text
GET  /api/sessions?accountKey=<account_key>&limit=50
POST /api/sessions
```

Memory context:

```text
GET /api/memory-context?accountKey=<account_key>&limit=6
```

## Tarot AI Loop

`pages/TarotView` and `pages/AIDialogPage` call the backend AI proxy through
`AppConfig.AI_CHAT_COMPLETIONS_PROXY_URL`.

For local verification:

```powershell
cd D:\do_it\first_fruit\echoing\backend
python server.py
```

Then check:

```text
http://127.0.0.1:8111/health
```

When running on a real HarmonyOS device, do not set the app proxy URL to
`127.0.0.1`; use the computer LAN IP and keep the `/v1/chat/completions` path,
for example `http://192.168.1.10:8111/v1/chat/completions`.

Minimal app path to verify:

```text
Index -> TarotView -> AI interpretation -> AIDialogPage -> ask follow-up -> ChatHistoryPage
```

## Admin APIs

Login:

```text
POST /api/auth/login
```

Use the returned token as:

```text
Authorization: Bearer <token>
```

Admin-only endpoints:

```text
GET    /api/auth/me
POST   /api/auth/logout
GET    /api/admin/leaves
DELETE /api/admin/leaves/<leaf_id>
POST   /api/admin/leaves/<leaf_id>/hide
POST   /api/admin/leaves/<leaf_id>/restore
GET    /api/admin/ai-history
```

For compatibility, this also works as an admin-only delete endpoint:

```text
DELETE /api/leaves/<leaf_id>
```

## SQLite

The database is initialized and migrated automatically on startup.

Tables:

- `schema_migrations`
- `shared_leaves`
- `app_users`
- `chat_sessions`
- `admin_users`
- `auth_sessions`
- `ai_history`

Shared leaves are kept visible for 7 days. Expired leaves are soft-deleted when the list endpoint is called.

App user accounts are separate from backend admin accounts. `admin_users` and
`auth_sessions` are only for the admin panel. App user identity is stored in
`app_users`, while AI and tarot memory are stored in `chat_sessions` and linked
by `account_key`.

Shared forest records can include `account_key` and `owner_nickname` so the
admin panel can see who published a leaf. Older shared leaves remain valid with
empty owner fields.

API keys are never stored in SQLite.

## Deployment

See `deploy/README.md` for systemd and nginx templates.
