# SnapRacers dedicated server

It's a SnapRacers game that's always there for people to join, with nobody of its own racing in it. Phones join it over Wi-Fi or the internet. The web version joins it too, which is the only way a web page can race online, since a browser can't host.

It runs the lobby by itself:
- A race starts a few seconds after everyone in the lobby says they're ready.
- AI drivers fill the empty places, if you want them.
- A cup moves on to its next race after the standings.
- Everyone goes back to the lobby at the end.

You run it from an admin page in your browser. There you pick what's raced, see who's in, kick anyone you need to, read the log and restart it.

## Running it with Docker

You need Docker with Compose. From this folder:

```sh
cp .env.example .env      # then set ADMIN_PASSWORD in it
docker compose up --build -d
```

The first build takes a few minutes. It downloads Godot, then imports and packs the game from this repo, so there's nothing to build first. When it's done, open `http://<this machine>:8080` and sign in with your password.

It runs in two containers:
- **snapracers-server** is the game itself, with no screen. Phones join it on port 27280 (UDP), and web players on 27282 (TCP).
- **snapracers-web** is the admin page, on port 8080. The races carry on without it.

Everything the server keeps lives in the `config` volume:
- its settings, in `server.json`
- your own courses, in the `courses` folder
- your own cups, in the `cups` folder

You'll see a line about `libfontconfig` in the server's log when it starts. That's fine: a server has no screen, so it never draws any text.

## Finding it

It's on host networking, so phones on the same Wi-Fi find it by themselves, in the list under **Host or join a game**. Two things put it there:
- The game server shouts about itself on the local network, the way a phone hosting a game does.
- The admin page puts out the NSD service Android phones look for.

Anywhere else, players type its address, which the dashboard shows. For the internet, open (forward) port 27280 UDP to it for phones, and 27282 TCP for web players.

On Docker Desktop, or to map the ports yourself, add the bridge file:

```sh
docker compose -f docker-compose.yml -f docker-compose.bridge.yml up --build -d
```

Phones won't find it by themselves that way, so set `ADVERTISE_ADDRESS` in `.env` to this machine's address. Then the dashboard shows players the right one to type.

## Web players need a certificate

A web page served over HTTPS, which is how the web version's put up, can only join a server over a secure WebSocket (`wss://`). That needs a certificate the player's browser trusts, for the name they type to join. A self signed one won't do, because browsers won't use it without asking, and a game can't ask.

If you have a domain pointing at the server, a free one from Let's Encrypt works:

1. Put the certificate and its key in a `certs` folder beside `docker-compose.yml`, readable by the container (it runs as user 10001).
2. Take the `#` off the `./certs:/certs:ro` line in `docker-compose.yml`.
3. Set these in `.env`, then `docker compose up -d` again:

   ```
   TLS_CERT=/certs/fullchain.pem
   TLS_KEY=/certs/privkey.pem
   ```

The dashboard says `wss://` once it's working. Web players type the server's name, like `races.example.com`, and the game adds the port.

Phones don't need any of this. They join over ENet on port 27280.

## Your own courses and cups

A course or cup you've made in the game is one JSON file, with everything in it. Copy them into the server's `courses` and `cups` folders in the `config` volume:

```sh
docker cp my_course.json snapracers-server:/config/courses/
```

Then they're in the lists on the Settings page. On a Linux PC, the game keeps yours in `~/.local/share/godot/app_userdata/SnapRacers/courses` and `cups`. A phone keeps them where only the game can see them. So from a phone, the easy way is to host a game: whoever hosts sends their course or cup to everyone in it.

## Running it without Docker

On a Linux PC with this repo, `tools/build-server.sh --run` builds the server into `/tmp/snapracers-build/server` and starts it. Its settings go in `~/.snapracers-server/server.json`, and it has no admin page that way. `tools/run-server-test.sh` races a player joining like a phone and one joining like a web page on it, to check it all works.

## How the admin page talks to the server

The game server listens for commands on 127.0.0.1:27289 only, so nothing off the machine can reach it. The admin page is the only thing that talks to it. A command is one line of tab separated words, and the answer is one line of JSON:

| Command | What it does |
| --- | --- |
| `status` | the server's name, what it's doing, who's in, and its settings |
| `courses`, `cups` | what it can put on |
| `set <name> <value>` | changes a setting and saves it |
| `start` | starts the race now, ready or not |
| `lobby` | stops the race and takes everyone back to the lobby |
| `kick <id>` | kicks a player |
| `log [after]` | what it's said lately |
| `restart` | quits, for Docker to start it again |
| `ping` | answers ok |

The settings are:
- `name`
- `mode`: `race` or `cup`
- `course`, `cup`, `laps`
- `ai`: true or false
- `difficulty`: easy, normal, hard or expert
- `start_after` and `standings_for`: in seconds
- `port`, `ws_port`, `tls_cert` and `tls_key`: these only take hold on a restart
