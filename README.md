# credfeto-ssh-key-server-docker

Docker compose for the SSH key server.

## Operations

Use these scripts from the repository root:

```bash
./install
./update
./reset
```

## Runtime data

- The key server data is stored in `/data/keyserver`.
- `install` and `update` ensure `/data/keyserver` exists, is owned by UID/GID `1654`, and is mounted into Docker as the external `keyserver-data` volume.
- `install` also creates `certs/server.pfx` locally when it is missing and mounts it into the container for TLS.
- The container image defaults to `docker-registry.markridgwell.com/credfeto/ssh-key-server:latest`.

## Secrets

- `install` generates a `.env` file (git-ignored) containing `CHALLENGE_HMAC_SECRET`, a random value passed to the container as `Challenge__HmacSecret`, if one does not already exist. It is never overwritten once created.
- `install` and `update` both refuse to run if `.env` is missing or `CHALLENGE_HMAC_SECRET` is unset — `update` never generates it, so a missing `.env` on an existing deployment means `install` needs to be run first.
- `docker-compose.yml` requires `CHALLENGE_HMAC_SECRET` to be set and will refuse to start otherwise.

## Network

- HTTP is published on `${PORT:-8080}` and mapped to container port `8080` for HTTP/1.1 and HTTP/2 cleartext.
- HTTPS is published on `${HTTPS_PORT:-8081}` and mapped to container port `8081` for HTTP/1.1, HTTP/2, and HTTP/3.
- `install` opens the configured HTTP and HTTPS ports (including UDP on the HTTPS port for HTTP/3) to private networks (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fc00::/7`, `fe80::/10`) via `firewall-cmd` when `firewalld` is present.
- Watchtower is included to keep the deployment up-to-date.
