"""One password, a signed cookie and a token on every form.

It's kept small on purpose. It's there because the page can kick players
and change what's raced, not to be a login system for a game server with
one person running it.
"""

import hashlib
import hmac
import os
import secrets

from itsdangerous import BadSignature, URLSafeTimedSerializer

COOKIE_NAME = "snapracers_admin"
MAX_AGE = int(os.environ.get("SESSION_MAX_AGE", str(7 * 24 * 3600)))


class MissingPassword(RuntimeError):
    pass


def password():
    value = os.environ.get("ADMIN_PASSWORD", "")
    if not value:
        # It won't start without one, so it can never come up open to
        # anyone just because a line was missing from the .env file.
        raise MissingPassword(
            "ADMIN_PASSWORD isn't set. The admin page can kick players and change "
            "what's raced, so it won't start without one. Put it in your .env file "
            "(see .env.example)."
        )
    return value


def _secret():
    # Made from the password, so a restart doesn't sign you out but a new
    # password does. SESSION_SECRET wins if it's set.
    explicit = os.environ.get("SESSION_SECRET", "")
    if explicit:
        return explicit
    return hashlib.sha256(("snapracers-session:" + password()).encode("utf-8")).hexdigest()


def check_password(candidate):
    # Compared in constant time, since the password is all there is.
    return hmac.compare_digest((candidate or "").encode("utf-8"), password().encode("utf-8"))


def issue_session():
    return URLSafeTimedSerializer(_secret()).dumps({"csrf": secrets.token_urlsafe(24)})


def read_session(token):
    if not token:
        return None
    try:
        return URLSafeTimedSerializer(_secret()).loads(token, max_age=MAX_AGE)
    except BadSignature:
        return None
    except Exception:
        return None


def csrf_ok(session, submitted):
    if not session:
        return False
    return hmac.compare_digest(session.get("csrf", ""), submitted or "")
