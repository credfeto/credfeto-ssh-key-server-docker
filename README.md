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

## Network

- HTTP is published on `${PORT:-8080}` and mapped to container port `8080` for HTTP/1.1 and HTTP/2 cleartext.
- HTTPS is published on `${HTTPS_PORT:-8443}` and mapped to container port `8443` for HTTP/1.1, HTTP/2, and HTTP/3.
- Ensure the host firewall allows the configured HTTP and HTTPS ports, including UDP on the HTTPS port for HTTP/3.
- Watchtower is included to keep the deployment up-to-date.
