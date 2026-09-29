"""The SnapRacers server's admin page.

It's one of the two containers in docker-compose.yml, and it keeps nothing of
its own: every page shows what the game server says over its control channel,
and every button is one command to it. If this isn't running, the races go on
just the same.
"""

import asyncio
import logging
import os
from contextlib import asynccontextmanager
from urllib.parse import urlencode

from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse, PlainTextResponse, RedirectResponse, Response
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from . import auth
from .control import Control, ControlError, ServerDown
from .discovery import Advertiser, lan_address

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))
LOG = logging.getLogger("snapracers.web")

HERE = os.path.dirname(os.path.abspath(__file__))
control = Control()

DIFFICULTIES = [("easy", "Easy"), ("normal", "Normal"), ("hard", "Hard"), ("expert", "Expert")]
# The settings that only take hold when the server starts again.
NEEDS_RESTART = ["port", "ws_port", "tls_cert", "tls_key"]
STATES = {"lobby": "In the lobby", "racing": "Racing", "standings": "Showing the cup standings"}


@asynccontextmanager
async def lifespan(app):
    # Stops the container straight away instead of serving an open page.
    auth.password()

    advertiser = Advertiser(
        enabled=os.environ.get("LAN_DISCOVERY", "1") not in ("0", "false", "no"),
        name=os.environ.get("SERVER_NAME", "SnapRacers server"),
        port=int(os.environ.get("GAME_PORT", "27280")),
        ws_port=int(os.environ.get("WS_PORT", "27282")),
    )

    # These run on a worker thread because the control channel and zeroconf
    # both block, and zeroconf refuses outright to run on the event loop's
    # thread. The name and ports follow the server, since they can be
    # changed on the settings page.
    async def keep_advertising():
        while True:
            try:
                status = await asyncio.to_thread(control.status)
                config = status.get("config", {})
                await asyncio.to_thread(
                    advertiser.update,
                    status.get("name") or advertiser.name,
                    int(config.get("port") or advertiser.port),
                    int(config.get("ws_port") or advertiser.ws_port),
                )
                await asyncio.to_thread(advertiser.start)
            except ServerDown:
                await asyncio.to_thread(advertiser.stop)
            except Exception as error:
                LOG.warning("I couldn't update what the local network sees: %s: %s", type(error).__name__, error)
            await asyncio.sleep(15)

    task = asyncio.create_task(keep_advertising())
    try:
        yield
    finally:
        task.cancel()
        # Saying goodbye means phones drop it from their list at once.
        await asyncio.to_thread(advertiser.stop)


app = FastAPI(title="SnapRacers server admin", lifespan=lifespan)
app.mount("/static", StaticFiles(directory=os.path.join(HERE, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(HERE, "templates"))


def session_of(request):
    return auth.read_session(request.cookies.get(auth.COOKIE_NAME))


def needs_login(request):
    """Off to the sign in page, or for a part of a page, a note to reload."""
    if request.headers.get("HX-Request"):
        return HTMLResponse("<p class='error'>You're signed out. Reload the page.</p>", status_code=401)
    return RedirectResponse("/login", status_code=303)


def render(request, template, **context):
    session = session_of(request)
    context.setdefault("csrf", session.get("csrf") if session else "")
    context.setdefault("notice", request.query_params.get("notice"))
    context.setdefault("error", request.query_params.get("error"))
    context.setdefault("server_name", os.environ.get("SERVER_NAME", "SnapRacers server"))
    context.setdefault("states", STATES)
    return templates.TemplateResponse(request, template, context)


def back(path, notice=None, error=None):
    query = urlencode({k: v for k, v in (("notice", notice), ("error", error)) if v})
    return RedirectResponse(f"{path}?{query}" if query else path, status_code=303)


def guard(request, csrf_token, back_to="/"):
    """Something to send back instead, or None to carry on."""
    session = session_of(request)
    if not session:
        return needs_login(request)
    if not auth.csrf_ok(session, csrf_token):
        return back(back_to, error="That page was out of date. Reload it and try again.")
    return None


def safe_status():
    try:
        status = control.status()
        status["running"] = True
        return status
    except (ServerDown, ControlError) as error:
        return {"running": False, "down": str(error), "players": []}


def addresses(status):
    """Where players join, for the dashboard to show."""
    here = os.environ.get("ADVERTISE_ADDRESS", "")
    if not here:
        try:
            here = lan_address()
        except OSError:
            here = "this machine's address"
    config = status.get("config", {})
    return {
        "phones": f"{here}:{config.get('port', 27280)}",
        "web": ("wss://" if status.get("secure") else "ws://") + f"{here}:{config.get('ws_port', 27282)}",
    }


# Signing in.

@app.get("/login", response_class=HTMLResponse)
def login_form(request: Request):
    if session_of(request):
        return RedirectResponse("/", status_code=303)
    return render(request, "login.html")


@app.post("/login")
def login(request: Request, password: str = Form("")):
    if not auth.check_password(password):
        return back("/login", error="That's not the admin password.")
    response = RedirectResponse("/", status_code=303)
    response.set_cookie(
        auth.COOKIE_NAME,
        auth.issue_session(),
        max_age=auth.MAX_AGE,
        httponly=True,
        samesite="lax",
        # Only when you've said there's HTTPS in front of it. Otherwise the
        # browser would never send the cookie back over plain HTTP.
        secure=os.environ.get("HTTPS", "0") in ("1", "true", "yes"),
    )
    return response


@app.post("/logout")
def logout():
    response = RedirectResponse("/login", status_code=303)
    response.delete_cookie(auth.COOKIE_NAME)
    return response


# The dashboard.

@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request):
    if not session_of(request):
        return needs_login(request)
    status = safe_status()
    return render(request, "dashboard.html", status=status, where=addresses(status))


@app.get("/fragments/status", response_class=HTMLResponse)
def fragment_status(request: Request):
    if not session_of(request):
        return needs_login(request)
    status = safe_status()
    return render(request, "fragments/status.html", status=status, where=addresses(status))


@app.get("/fragments/players", response_class=HTMLResponse)
def fragment_players(request: Request):
    if not session_of(request):
        return needs_login(request)
    return render(request, "fragments/players.html", status=safe_status())


@app.get("/fragments/log", response_class=HTMLResponse)
def fragment_log(request: Request, limit: int = 40):
    if not session_of(request):
        return needs_login(request)
    try:
        lines = control.log()[-limit:]
    except (ServerDown, ControlError):
        lines = []
    return render(request, "fragments/log.html", lines=lines)


@app.post("/race/{action}")
def race(request: Request, action: str, csrf: str = Form(""), player: str = Form("")):
    stop = guard(request, csrf)
    if stop:
        return stop
    try:
        if action == "start":
            control.start()
            return back("/", notice="Starting the race.")
        if action == "lobby":
            control.lobby()
            return back("/", notice="Everyone's back in the lobby.")
        if action == "kick":
            control.kick(player)
            return back("/", notice="They're gone.")
        if action == "restart":
            control.restart()
            return back("/", notice="Restarting. Anyone who was in it has to join again.")
    except ControlError as error:
        return back("/", error=str(error))
    except ServerDown:
        return back("/", error="The server isn't running.")
    return back("/", error=f"I don't know how to {action}.")


# The settings.

@app.get("/settings", response_class=HTMLResponse)
def settings(request: Request):
    if not session_of(request):
        return needs_login(request)
    try:
        status = control.status()
        courses = control.courses()
        cups = control.cups()
    except (ServerDown, ControlError) as error:
        return render(request, "settings.html", down=str(error))
    return render(
        request,
        "settings.html",
        config=status.get("config", {}),
        courses=courses,
        cups=cups,
        difficulties=DIFFICULTIES,
    )


@app.post("/settings")
async def save_settings(request: Request):
    form = await request.form()
    stop = guard(request, form.get("csrf", ""), "/settings")
    if stop:
        return stop
    try:
        config = control.status().get("config", {})
    except (ServerDown, ControlError) as error:
        return back("/settings", error=str(error))

    wanted = {}
    for name in ("name", "mode", "course", "cup", "laps", "difficulty", "start_after", "standings_for",
                 "port", "ws_port", "tls_cert", "tls_key"):
        if name in form:
            wanted[name] = str(form.get(name)).strip()
    # A box that isn't ticked isn't sent at all.
    wanted["ai"] = "true" if form.get("ai") else "false"

    changed, refused, restart = 0, [], False
    for name, value in wanted.items():
        now = config.get(name)
        now = ("true" if now else "false") if isinstance(now, bool) else _plain(now)
        if value == now:
            continue
        try:
            reply = control.set(name, value)
            changed += 1
            restart = restart or reply.get("restart", False)
        except ControlError as error:
            refused.append(str(error))
        except ServerDown as error:
            return back("/settings", error=str(error))

    note = "Nothing changed." if changed == 0 else f"Saved {changed} setting{'' if changed == 1 else 's'}. They're used from the next race."
    if restart:
        note += " The ports and certificate are only used once the server starts again."
    return back("/settings", notice=note, error="; ".join(refused[:4]) or None)


def _plain(value):
    """A setting the way the form shows it, so 3.0 and 3 are the same."""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return "" if value is None else str(value)


# The log.

@app.get("/logs", response_class=HTMLResponse)
def logs(request: Request):
    if not session_of(request):
        return needs_login(request)
    return render(request, "logs.html")


@app.get("/logs/download")
def download_logs(request: Request):
    if not session_of(request):
        return needs_login(request)
    try:
        lines = control.log()
    except (ServerDown, ControlError):
        lines = []
    body = "\n".join(f"[{line[1]}] {line[2]}" for line in lines) + "\n"
    return Response(body, media_type="text/plain",
                    headers={"Content-Disposition": "attachment; filename=snapracers-server.log"})


@app.get("/healthz", response_class=PlainTextResponse)
def healthz():
    try:
        control.call("ping")
        return "ok"
    except ServerDown:
        return PlainTextResponse("the server's down", status_code=503)
