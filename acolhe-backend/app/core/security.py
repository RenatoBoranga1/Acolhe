from __future__ import annotations

import base64
import hashlib
import hmac
import os


def hash_pin(pin: str) -> str:
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", pin.encode("utf-8"), salt, 200_000)
    return f"{base64.b64encode(salt).decode()}:{base64.b64encode(digest).decode()}"


def verify_pin(pin: str, hashed_pin: str) -> bool:
    salt_b64, digest_b64 = hashed_pin.split(":")
    salt = base64.b64decode(salt_b64.encode())
    expected = base64.b64decode(digest_b64.encode())
    candidate = hashlib.pbkdf2_hmac("sha256", pin.encode("utf-8"), salt, 200_000)
    return hmac.compare_digest(candidate, expected)


def redact_text(value: str | None) -> str:
    if not value:
        return ""
    return f"[redacted:{min(len(value), 12)}]"
