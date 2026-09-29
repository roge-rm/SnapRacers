# The SnapRacers server's admin page.
#
# It keeps nothing of its own. Every page shows what the game server says
# over its control channel, and every button is one command to it, so this
# can be restarted, or left out, without the races noticing.

FROM python:3.13-slim

RUN groupadd --gid 10001 snapracers \
 && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin snapracers

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app /app/app

ENV WEB_PORT=8080 \
    WEB_BIND=0.0.0.0 \
    LAN_DISCOVERY=1

EXPOSE 8080/tcp

USER snapracers

# A shell, so WEB_BIND and WEB_PORT come from the environment. On host
# networking there's no published port to change instead.
CMD ["sh", "-c", "exec uvicorn app.main:app --host \"$WEB_BIND\" --port \"$WEB_PORT\" --proxy-headers"]
