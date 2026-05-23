# Echoing backend deployment

This deployment path keeps the backend dependency-free: Python 3 standard library plus SQLite.

## Suggested server layout

```text
/opt/echoing/backend
/var/lib/echoing
```

Copy `backend/` to `/opt/echoing/backend`, then create `/opt/echoing/backend/.env` from `deploy/echoing.env.example`.

Use a strong `ADMIN_PASSWORD` before the first boot. The backend creates the first admin user only when the admin table is empty.

If an existing deployment already has a database path in `/health`, keep that
path unless you intentionally migrate the database. The current production
instance observed at `139.59.99.182` reports:

```text
ECHOING_DB_PATH=/opt/echoing/backend/data/echoing.db
```

Do not replace the server `.env` during redeploy unless you have reviewed every
value. In particular, preserve `MODELSCOPE_API_KEY`, `ADMIN_PASSWORD`, and
`ECHOING_DB_PATH`.

## Pre-deploy checks

Run locally before uploading:

```powershell
python -m compileall backend
```

Check the target server before changing files:

```bash
curl http://127.0.0.1:8111/health
sudo systemctl status echoing-backend --no-pager
```

Back up the active SQLite database first:

```bash
sudo mkdir -p /var/backups/echoing
sudo cp /opt/echoing/backend/data/echoing.db /var/backups/echoing/echoing.$(date +%Y%m%d-%H%M%S).db
```

If your server uses `/var/lib/echoing/echoing.db` instead, back up that file
instead. The safe source of truth is the `database` field returned by `/health`.

## systemd

```bash
sudo useradd --system --home /opt/echoing --shell /usr/sbin/nologin echoing
sudo mkdir -p /opt/echoing /var/lib/echoing
sudo chown -R echoing:echoing /opt/echoing /var/lib/echoing
sudo cp deploy/echoing-backend.service /etc/systemd/system/echoing-backend.service
sudo systemctl daemon-reload
sudo systemctl enable --now echoing-backend
sudo systemctl status echoing-backend
```

## Redeploy existing backend

For an existing server, stop the service, upload only backend code changes, keep
`.env` and `data/` on the server, then restart:

```bash
sudo systemctl stop echoing-backend

# Upload/replace backend source files under /opt/echoing/backend.
# Preserve these server-side files/directories:
# - /opt/echoing/backend/.env
# - /opt/echoing/backend/data/

sudo chown -R echoing:echoing /opt/echoing/backend
sudo systemctl daemon-reload
sudo systemctl start echoing-backend
sudo systemctl status echoing-backend --no-pager
curl http://127.0.0.1:8111/health
curl http://127.0.0.1:8111/api/leaves
```

The SQLite migrations run automatically when the backend starts. The new
account-related migrations are additive and keep old rows compatible.

## nginx

Copy `deploy/nginx-echoing.conf` to your nginx site directory, replace `example.com`, then reload nginx.

```bash
sudo nginx -t
sudo systemctl reload nginx
```

The admin panel is available at `/admin`.
