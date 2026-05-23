from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


ROOT = Path(__file__).resolve().parent


def load_dotenv() -> None:
    env_path = ROOT / ".env"
    if not env_path.exists():
        return

    for line in env_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


load_dotenv()

API_KEY = os.environ.get("MODELSCOPE_API_KEY", "")
API_BASE = os.environ.get("MODELSCOPE_API_BASE", "https://api-inference.modelscope.cn/v1").rstrip("/")
DEFAULT_MODEL = os.environ.get("MODELSCOPE_MODEL", "Qwen/Qwen2.5-72B-Instruct")
HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8111"))

from database import DB_PATH, init_database
from services.ai_history_service import AIHistoryService
from services.app_user_service import AppUserError, AppUserService
from services.auth_service import AuthError, AuthService
from services.chat_session_service import ChatSessionError, ChatSessionService
from services.shared_forest_service import NotFoundError, SharedForestService, ValidationError


shared_forest_service = SharedForestService()
auth_service = AuthService()
ai_history_service = AIHistoryService()
app_user_service = AppUserService()
chat_session_service = ChatSessionService()


class ProxyHandler(BaseHTTPRequestHandler):
    server_version = "EchoingAIProxy/0.1"

    def do_OPTIONS(self) -> None:
        self.send_json(204, None)

    def do_GET(self) -> None:
        route = urlparse(self.path)
        if route.path == "/health":
            self.send_json(
                200,
                {
                    "ok": True,
                    "provider": "modelscope",
                    "api_base": API_BASE,
                    "database": str(DB_PATH),
                },
            )
            return
        if route.path == "/admin":
            self.send_admin_page()
            return
        if route.path == "/api/leaves":
            query = parse_qs(route.query)
            limit = self.parse_int(query.get("limit", ["100"])[0], 100)
            self.send_json(200, shared_forest_service.list_leaves(limit))
            return
        if route.path == "/api/sessions":
            query = parse_qs(route.query)
            account_key = self.resolve_account_key(query=query)
            if not account_key:
                self.send_json(400, {"error": "accountKey is required"})
                return
            limit = self.parse_int(query.get("limit", ["100"])[0], 100)
            self.send_json(200, chat_session_service.list_sessions(account_key, limit))
            return
        if route.path == "/api/memory-context":
            query = parse_qs(route.query)
            account_key = self.resolve_account_key(query=query)
            if not account_key:
                self.send_json(200, {"context": "", "count": 0})
                return
            limit = self.parse_int(query.get("limit", ["5"])[0], 5)
            self.send_json(200, chat_session_service.memory_context(account_key, limit))
            return
        if route.path == "/api/auth/me":
            try:
                user = self.require_admin()
                self.send_json(200, {"user": user})
            except AuthError as exc:
                self.send_json(401, {"error": str(exc)})
            return
        if route.path == "/api/admin/leaves":
            try:
                self.require_admin()
                query = parse_qs(route.query)
                limit = self.parse_int(query.get("limit", ["100"])[0], 100)
                status = query.get("status", [None])[0]
                self.send_json(200, shared_forest_service.list_admin_leaves(limit, status))
            except AuthError as exc:
                self.send_json(401, {"error": str(exc)})
            return
        if route.path == "/api/admin/ai-history":
            try:
                self.require_admin()
                query = parse_qs(route.query)
                limit = self.parse_int(query.get("limit", ["100"])[0], 100)
                self.send_json(200, ai_history_service.list_recent(limit))
            except AuthError as exc:
                self.send_json(401, {"error": str(exc)})
            return
        self.send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        route = urlparse(self.path)
        if route.path == "/api/auth/login":
            try:
                payload = self.read_json_body()
                username = str(payload.get("username", ""))
                password = str(payload.get("password", ""))
                self.send_json(200, auth_service.login(username, password))
            except AuthError as exc:
                self.send_json(401, {"error": str(exc)})
            except json.JSONDecodeError:
                self.send_json(400, {"error": "Request body must be valid JSON"})
            return

        if route.path == "/api/auth/logout":
            auth_service.logout(self.headers.get("Authorization"))
            self.send_json(200, {"ok": True})
            return

        if route.path == "/api/leaves":
            try:
                payload = self.read_json_body()
                account_key = self.resolve_account_key(payload=payload)
                if account_key:
                    payload["accountKey"] = account_key
                self.send_json(200, shared_forest_service.create_leaf(payload))
            except (ValidationError, AppUserError) as exc:
                self.send_json(400, {"error": str(exc)})
            except json.JSONDecodeError:
                self.send_json(400, {"error": "Request body must be valid JSON"})
            except Exception as exc:
                self.send_json(500, {"error": str(exc)})
            return

        if route.path == "/api/app-users/upsert":
            try:
                payload = self.read_json_body()
                self.send_json(200, {"user": app_user_service.upsert(payload)})
            except AppUserError as exc:
                self.send_json(400, {"error": str(exc)})
            except json.JSONDecodeError:
                self.send_json(400, {"error": "Request body must be valid JSON"})
            return

        if route.path == "/api/sessions":
            try:
                payload = self.read_json_body()
                account_key = self.resolve_account_key(payload=payload)
                self.send_json(200, chat_session_service.save_session(payload, account_key))
            except (ChatSessionError, AppUserError) as exc:
                self.send_json(400, {"error": str(exc)})
            except json.JSONDecodeError:
                self.send_json(400, {"error": "Request body must be valid JSON"})
            return

        if route.path.startswith("/api/leaves/") and route.path.endswith("/like"):
            leaf_id = route.path.removeprefix("/api/leaves/").removesuffix("/like").strip("/")
            try:
                self.send_json(200, shared_forest_service.like_leaf(leaf_id))
            except ValidationError as exc:
                self.send_json(400, {"error": str(exc)})
            except NotFoundError as exc:
                self.send_json(404, {"error": str(exc)})
            except Exception as exc:
                self.send_json(500, {"error": str(exc)})
            return

        if route.path.startswith("/api/admin/leaves/") and route.path.endswith("/restore"):
            leaf_id = route.path.removeprefix("/api/admin/leaves/").removesuffix("/restore").strip("/")
            try:
                self.require_admin()
                self.send_json(200, shared_forest_service.restore_leaf(leaf_id))
            except AuthError as exc:
                self.send_json(401, {"error": str(exc)})
            except ValidationError as exc:
                self.send_json(400, {"error": str(exc)})
            except NotFoundError as exc:
                self.send_json(404, {"error": str(exc)})
            return

        if route.path.startswith("/api/admin/leaves/") and route.path.endswith("/hide"):
            leaf_id = route.path.removeprefix("/api/admin/leaves/").removesuffix("/hide").strip("/")
            try:
                self.require_admin()
                payload = self.read_json_body()
                reason = str(payload.get("reason", "manual moderation"))
                self.send_json(200, shared_forest_service.hide_leaf(leaf_id, reason))
            except AuthError as exc:
                self.send_json(401, {"error": str(exc)})
            except ValidationError as exc:
                self.send_json(400, {"error": str(exc)})
            except NotFoundError as exc:
                self.send_json(404, {"error": str(exc)})
            except json.JSONDecodeError:
                self.send_json(400, {"error": "Request body must be valid JSON"})
            return

        if route.path != "/v1/chat/completions":
            self.send_json(404, {"error": "not_found"})
            return

        if not API_KEY:
            self.send_json(500, {"error": "MODELSCOPE_API_KEY is not configured"})
            return

        try:
            start = time.monotonic()
            body = self.read_json_body()
            account_key = self.resolve_account_key(payload=body)
            app_user = None
            if account_key:
                app_user = app_user_service.upsert(
                    {
                        "accountKey": account_key,
                        "nickname": body.get("nickname", ""),
                        "bio": body.get("bio", ""),
                    }
                )
            forward_body = self.sanitize_chat_completion_body(body)
            forward_body["model"] = DEFAULT_MODEL
            upstream = self.forward_chat_completions(forward_body)
            ai_history_service.record(
                model=DEFAULT_MODEL,
                request_body=forward_body,
                response_body=upstream,
                status="success",
                error_message="",
                latency_ms=int((time.monotonic() - start) * 1000),
                client_ip=self.client_address[0],
                app_user_id=str(app_user["id"]) if app_user else None,
                account_key=account_key,
            )
            self.send_json(200, upstream)
        except urllib.error.HTTPError as exc:
            error_body = exc.read().decode("utf-8", errors="replace")
            ai_history_service.record(
                model=DEFAULT_MODEL,
                request_body=locals().get("forward_body", locals().get("body", {})),
                response_body=None,
                status="upstream_error",
                error_message=error_body or exc.reason,
                latency_ms=int((time.monotonic() - locals().get("start", time.monotonic())) * 1000),
                client_ip=self.client_address[0],
                app_user_id=str(locals().get("app_user", {}).get("id")) if locals().get("app_user") else None,
                account_key=locals().get("account_key", ""),
            )
            self.send_json(
                exc.code,
                {
                    "error": "upstream_error",
                    "status": exc.code,
                    "message": error_body or exc.reason,
                },
            )
            print(f"ModelScope upstream error {exc.code}: {error_body or exc.reason}")
        except json.JSONDecodeError:
            self.send_json(400, {"error": "Request body must be valid JSON"})
        except Exception as exc:
            ai_history_service.record(
                model=DEFAULT_MODEL,
                request_body=locals().get("forward_body", locals().get("body", {})),
                response_body=None,
                status="failed",
                error_message=str(exc),
                latency_ms=int((time.monotonic() - locals().get("start", time.monotonic())) * 1000),
                client_ip=self.client_address[0],
                app_user_id=str(locals().get("app_user", {}).get("id")) if locals().get("app_user") else None,
                account_key=locals().get("account_key", ""),
            )
            self.send_json(500, {"error": str(exc)})

    def do_DELETE(self) -> None:
        route = urlparse(self.path)
        if route.path.startswith("/api/sessions/"):
            session_id = route.path.removeprefix("/api/sessions/").strip("/")
            query = parse_qs(route.query)
            account_key = self.resolve_account_key(query=query)
            if not account_key:
                self.send_json(400, {"error": "accountKey is required"})
                return
            try:
                self.send_json(200, chat_session_service.delete_session(session_id, account_key))
            except AppUserError as exc:
                self.send_json(400, {"error": str(exc)})
            return
        if route.path.startswith("/api/leaves/"):
            leaf_id = route.path.removeprefix("/api/leaves/").strip("/")
            self.delete_leaf_as_admin(leaf_id)
            return
        if route.path.startswith("/api/admin/leaves/"):
            leaf_id = route.path.removeprefix("/api/admin/leaves/").strip("/")
            self.delete_leaf_as_admin(leaf_id)
            return
        self.send_json(404, {"error": "not_found"})

    def delete_leaf_as_admin(self, leaf_id: str) -> None:
        try:
            user = self.require_admin()
            self.send_json(200, shared_forest_service.delete_leaf(leaf_id, user))
        except AuthError as exc:
            self.send_json(401, {"error": str(exc)})
        except ValidationError as exc:
            self.send_json(400, {"error": str(exc)})
        except NotFoundError as exc:
            self.send_json(404, {"error": str(exc)})

    def parse_int(self, value: str, fallback: int) -> int:
        try:
            return int(value)
        except ValueError:
            return fallback

    def read_json_body(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        if not raw:
            return {}
        parsed = json.loads(raw.decode("utf-8"))
        if not isinstance(parsed, dict):
            raise ValueError("Request body must be a JSON object")
        return parsed

    def resolve_account_key(
        self,
        payload: dict[str, Any] | None = None,
        query: dict[str, list[str]] | None = None,
    ) -> str:
        header_key = self.headers.get("X-Account-Key") or self.headers.get("X-User-Id") or ""
        if header_key.strip():
            return header_key.strip()
        if query:
            query_key = query.get("accountKey", [""])[0] or query.get("userId", [""])[0]
            if query_key.strip():
                return query_key.strip()
        if payload:
            payload_key = str(payload.get("accountKey") or payload.get("account_key") or payload.get("userId") or "")
            if payload_key.strip():
                return payload_key.strip()
        return ""

    def sanitize_chat_completion_body(self, body: dict[str, Any]) -> dict[str, Any]:
        blocked_keys = {
            "accountKey",
            "account_key",
            "userId",
            "user_id",
            "nickname",
            "bio",
            "provider",
            "externalId",
            "external_id",
        }
        return {key: value for key, value in body.items() if key not in blocked_keys}

    def require_admin(self) -> dict[str, Any]:
        user = auth_service.require_user(self.headers.get("Authorization"))
        if user.get("role") != "admin":
            raise AuthError("admin role is required")
        return user

    def forward_chat_completions(self, body: dict[str, Any]) -> dict[str, Any]:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            f"{API_BASE}/chat/completions",
            data=data,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {API_KEY}",
            },
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            response_body = response.read().decode("utf-8")
        parsed = json.loads(response_body)
        if not isinstance(parsed, dict):
            raise ValueError("Upstream response must be a JSON object")
        return parsed

    def send_json(self, status: int, payload: dict[str, Any] | None) -> None:
        self.send_response(status)
        self.send_cors_headers()
        if payload is None:
            self.end_headers()
            return
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_raw(self, status: int, payload: str) -> None:
        data = payload.encode("utf-8")
        self.send_response(status)
        self.send_cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_html(self, status: int, payload: str) -> None:
        data = payload.encode("utf-8")
        self.send_response(status)
        self.send_cors_headers()
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_admin_page(self) -> None:
        admin_path = ROOT / "admin.html"
        if not admin_path.exists():
            self.send_json(404, {"error": "admin page not found"})
            return
        self.send_html(200, admin_path.read_text(encoding="utf-8"))

    def send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-User-Id, X-Account-Key")

    def log_message(self, format: str, *args: Any) -> None:
        print("%s - %s" % (self.address_string(), format % args))


def main() -> None:
    init_database()
    auth_service.bootstrap_admin_from_env()
    httpd = ThreadingHTTPServer((HOST, PORT), ProxyHandler)
    print(f"Echoing backend listening on http://{HOST}:{PORT}")
    print(f"Forwarding chat completions to {API_BASE}/chat/completions")
    print(f"Shared forest SQLite database: {DB_PATH}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
