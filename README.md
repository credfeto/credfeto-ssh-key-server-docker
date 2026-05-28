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
- The container image defaults to `docker-registry.markridgwell.com/credfeto/ssh-key-server:latest`.

## Network

- The SSH key server is published on `${PORT:-8080}` and mapped to container port `8080`.
- Watchtower is included to keep the deployment up-to-date.
