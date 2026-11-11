# SnapRacers dedicated server

The dedicated server hosts races for phones and browsers, with no player of its own. It starts a race when everyone is ready, fills empty places with AI if you want, moves cups on after the standings and returns everyone to the lobby at the end.

The admin page lets you pick the race or cup, change settings, see who's joined, kick players, read the log and restart the server.

## Running with Docker

You need Docker with Compose. From `server/`, copy the settings file:

```sh
cp .env.example .env
```

Set `ADMIN_PASSWORD` in `.env`, then start it:

```sh
docker compose up --build -d
```

The first build downloads Godot and packs the game. Open `http://<server address>:8080` and sign in with your password.

There are two containers:

| Container | What it runs | Default ports |
|---|---|---|
| `snapracers-server` | The game server | 27280 UDP for phones, 27282 TCP for browsers |
| `snapracers-web` | The admin page | 8080 TCP |

The game keeps running if the admin page stops. Settings are in `server.json`, and custom courses and cups are in `courses/` and `cups/`, all in the Docker `config` volume. Back up that volume to keep them.

The startup message about `libfontconfig` is harmless on the server.

## Connecting

On the same Wi-Fi, phones find the server under Host or join a game. The default Docker setup uses host networking so local discovery works.

Elsewhere, players enter the address shown on the dashboard. For internet games, forward port 27280 UDP for phones and 27282 TCP for browsers. If you change `GAME_PORT` or `WS_PORT` in `.env`, use those ports instead.

For Docker Desktop or mapped ports, start with the bridge file too:

```sh
docker compose -f docker-compose.yml -f docker-compose.bridge.yml up --build -d
```

With bridge networking, players enter the address themselves. Set `ADVERTISE_ADDRESS` in `.env` to the address they should use so the dashboard shows it.

## Browser connections

The browser game is served over HTTPS and needs a secure WebSocket (`wss://`) to join. Give the server a certificate trusted by the browser for its domain name, for example one from Let's Encrypt.

1. Put the certificate and key in `server/certs/`. Both must be readable by user 10001 in the container.
2. Uncomment `./certs:/certs:ro` in `docker-compose.yml`.
3. Set these paths in `.env`:

   ```ini
   TLS_CERT=/certs/fullchain.pem
   TLS_KEY=/certs/privkey.pem
   ```

4. Run `docker compose up -d` again, using the bridge file too if that's how you started it.

The dashboard shows `wss://` when the certificate is loaded. Browser players enter the domain name, such as `races.example.com`, and the game adds the port. Phone connections use ENet and don't need this certificate.

## Adding courses and cups

Each course or cup saved by the game is a JSON file. Copy it into the matching folder in the server's `config` volume:

```sh
docker cp my_course.json snapracers-server:/config/courses/
docker cp my_cup.json snapracers-server:/config/cups/
```

They then appear on the admin page under Settings. On Linux, the game saves courses and cups in `~/.local/share/godot/app_userdata/SnapRacers/courses` and `cups`. From a phone you can share a course or cup as a file, or host a game on the phone to send it to everyone joining.

## Running without Docker

On Linux, set up the Godot tools described in the [main README](../README.md#building). From the repo's root, run:

```sh
tools/build-server.sh --run
```

The build goes in `build/server` and settings in `~/.snapracers-server/server.json`, with custom courses and cups in `courses/` and `cups/` beside it. Set `SNAPRACERS_CONFIG` to use a different settings file. This starts the game server without the admin page.

From the repo's root, `tools/run-server-test.sh` starts a test server and races a phone connection and a browser connection against each other. Use `tools/run-server-test.sh --running` to test one that's already running.

## Admin commands

The server accepts commands on `127.0.0.1:27289`. The admin page shares its network so it can reach that port. Each command is one line of tab separated words, with one line of JSON returned.

| Command | What it does |
|---|---|
| `status` | Lists the server's name, state, players and settings. |
| `courses`, `cups` | Lists available courses or cups. |
| `set <name> <value>` | Changes and saves a setting. |
| `start` | Starts a race without waiting for everyone to be ready. |
| `lobby` | Ends the race and returns players to the lobby. |
| `kick <id>` | Disconnects a player. |
| `log [after]` | Returns recent log entries. |
| `restart` | Quits so Docker can restart the server. |
| `ping` | Returns `{"ok": true}`. |

These settings can be changed with `set`:

| Setting | Values |
|---|---|
| `name` | Server name. |
| `mode` | `race` or `cup`. |
| `course`, `cup` | Course or cup ID. |
| `laps` | Number of laps. |
| `ai` | `true` or `false`. |
| `difficulty` | `easy`, `normal`, `hard` or `expert`. |
| `weather` | `random`, `clear`, `rain`, `snow`, `fog`, `storm` or `dust`. |
| `time` | `random`, `morning`, `day`, `evening`, `dusk` or `night`. |
| `reversed`, `mirrored` | `on` or `off`. |
| `start_after`, `standings_for` | Seconds before starting and seconds on the standings. After a cup's last race the podium plays for 10 seconds first, and the standings then stay up for at least 5 seconds. |
| `port`, `ws_port` | Phone and browser ports. Requires a restart. |
| `tls_cert`, `tls_key` | Certificate and key paths. Requires a restart. |

Docker sets the ports and certificate paths from `.env` each time it starts, so change them there when running with Compose.
