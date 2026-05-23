from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Mapping
from uuid import uuid4

from database import get_connection
from repositories.app_user_repository import AppUserRepository


class AppUserError(ValueError):
    pass


class AppUserService:
    def upsert(self, payload: Mapping[str, Any]) -> dict[str, Any]:
        account_key = self._normalize_text(payload.get("accountKey") or payload.get("account_key"))
        if not account_key:
            raise AppUserError("accountKey is required")

        provider = self._normalize_text(payload.get("provider"))
        external_id = self._normalize_text(payload.get("externalId") or payload.get("external_id"))
        nickname = self._normalize_text(payload.get("nickname"))
        bio = self._normalize_text(payload.get("bio"))
        now = self._format_time(self._now())

        with get_connection() as connection:
            repository = AppUserRepository(connection)
            existing = repository.get_by_account_key(account_key)
            if existing is None:
                return repository.create(
                    user_id=f"app_{uuid4().hex}",
                    account_key=account_key,
                    provider=provider,
                    external_id=external_id,
                    nickname=nickname,
                    bio=bio,
                    now=now,
                )
            if nickname or bio or provider or external_id:
                return repository.update_profile(account_key, provider, external_id, nickname, bio, now)
            touched = repository.touch(account_key, now)
            if touched is None:
                raise RuntimeError("App user disappeared while touching")
            return touched

    def get_or_create_from_identity(
        self,
        account_key: str,
        nickname: str = "",
        bio: str = "",
    ) -> dict[str, Any]:
        return self.upsert({"accountKey": account_key, "nickname": nickname, "bio": bio})

    def _normalize_text(self, value: Any) -> str:
        if value is None:
            return ""
        return str(value).strip()

    def _now(self) -> datetime:
        return datetime.now(timezone.utc)

    def _format_time(self, value: datetime) -> str:
        return value.strftime("%Y-%m-%d %H:%M:%S")
