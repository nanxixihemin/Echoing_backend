from __future__ import annotations

import sqlite3
from typing import Any


class AppUserRepository:
    def __init__(self, connection: sqlite3.Connection) -> None:
        self.connection = connection

    def get_by_account_key(self, account_key: str) -> dict[str, Any] | None:
        row = self.connection.execute(
            """
            SELECT id, account_key, provider, external_id, nickname, bio,
                   created_at, updated_at, last_seen_at
            FROM app_users
            WHERE account_key = ?
            """,
            (account_key,),
        ).fetchone()
        return dict(row) if row else None

    def create(
        self,
        user_id: str,
        account_key: str,
        provider: str,
        external_id: str,
        nickname: str,
        bio: str,
        now: str,
    ) -> dict[str, Any]:
        self.connection.execute(
            """
            INSERT INTO app_users(
              id, account_key, provider, external_id, nickname, bio,
              created_at, updated_at, last_seen_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (user_id, account_key, provider, external_id, nickname, bio, now, now, now),
        )
        row = self.get_by_account_key(account_key)
        if row is None:
            raise RuntimeError("Created app user cannot be loaded")
        return row

    def update_profile(
        self,
        account_key: str,
        provider: str,
        external_id: str,
        nickname: str,
        bio: str,
        now: str,
    ) -> dict[str, Any]:
        self.connection.execute(
            """
            UPDATE app_users
            SET provider = COALESCE(NULLIF(?, ''), provider),
                external_id = COALESCE(NULLIF(?, ''), external_id),
                nickname = ?,
                bio = ?,
                updated_at = ?,
                last_seen_at = ?
            WHERE account_key = ?
            """,
            (provider, external_id, nickname, bio, now, now, account_key),
        )
        row = self.get_by_account_key(account_key)
        if row is None:
            raise RuntimeError("Updated app user cannot be loaded")
        return row

    def touch(self, account_key: str, now: str) -> dict[str, Any] | None:
        self.connection.execute(
            "UPDATE app_users SET last_seen_at = ? WHERE account_key = ?",
            (now, account_key),
        )
        return self.get_by_account_key(account_key)
