# credfeto-ssh-key-server-docker

Docker compose for the SSH key server.

## Operations

Use these scripts from the repository root:

```bash
./install
./update
./reset
./add-key
./delete-key
./list-keys
```

## Key management

These scripts manage the keys held by the running `ssh-key-server` container. Each one runs the server's admin CLI (`/usr/src/app/Credfeto.Keys.Server`) inside the container with `sudo docker compose exec`, as the container's runtime user (UID/GID `1654`), and requires `docker`, `sudo` and an existing `.env` (run `./install` first).

```bash
./add-key --host server1 --username alice --key "ssh-ed25519 AAAA... alice@laptop"
./add-key --host server1 --username alice --key-file ~/.ssh/id_ed25519.pub
./add-key --host server1 --username alice < ~/.ssh/id_ed25519.pub
./delete-key --host server1 --username alice --fingerprint SHA256:...
./delete-key --host server1 --username alice --key "ssh-ed25519 AAAA... alice@laptop"
./list-keys --host server1
```

| Script       | Arguments                                                                                    | Description                                                                                                  |
|--------------|----------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| `add-key`    | `--host` and `--username` (required); `--key <public key>` or `--key-file <file>` (optional) | Adds a public key. Without `--key` or `--key-file` the key is read from stdin. Only the first line is used.  |
| `delete-key` | `--host` and `--username` (required); exactly one of `--key` or `--fingerprint`              | Deletes a key, identified by its public key line or its fingerprint.                                         |
| `list-keys`  | `--host` and `--username` (both optional filters)                                            | Lists the stored keys.                                                                                       |

- Every script accepts `-h` or `--help` to print its usage.
- Output is whatever the server's CLI prints; the scripts add nothing to it.
- Exit codes:
  - `0`: the command succeeded.
  - `1`: `docker`, `sudo` or `.env` is missing.
  - `2`: usage error (missing or unknown argument, both `--key` and `--key-file`, both `--key` and `--fingerprint`, or an empty key); the usage is printed to stderr.
  - Any other code is passed through unchanged from `docker compose exec` and the server's CLI.

## Runtime data

- The key server data is stored in `/data/keyserver`.
- `install` and `update` ensure `/data/keyserver` exists, is owned by UID/GID `1654`, and is mounted into Docker as the external `keyserver-data` volume.
- `install` also creates `certs/server.pfx` locally when it is missing and mounts it into the container for TLS.
- The container image defaults to `docker-registry.markridgwell.com/credfeto/ssh-key-server:latest`.

## Secrets

- `install` generates a `.env` file (git-ignored) containing `CHALLENGE_HMAC_SECRET`, a random value passed to the container as `Challenge__HmacSecret`, if one does not already exist. It is never overwritten once created.
- `install` and `update` both refuse to run if `.env` is missing or `CHALLENGE_HMAC_SECRET` is unset — `update` never generates it, so a missing `.env` on an existing deployment means `install` needs to be run first.
- `docker-compose.yml` requires `CHALLENGE_HMAC_SECRET` to be set and will refuse to start otherwise.

## Backup

The `git-backup` sidecar backs up the key data to a private GitHub repository using a deploy key.

### Setup

1. Create a private GitHub repository to hold the backup.
2. Generate a dedicated SSH key pair, for example `ssh-keygen -t ed25519 -N '' -f ~/.ssh/ssh-key-server-backup`.
3. Add the public key to the repository as a deploy key with write access.
4. Run `./install` once on a fresh checkout: it creates `.env` and then stops because the backup settings are missing.
5. Add the settings below to `.env`, then run `./install` again.

| Variable                  | Required | Default                                          | Description                                          |
|---------------------------|----------|--------------------------------------------------|------------------------------------------------------|
| `BACKUP_SSH_KEY`          | Yes      |                                                  | Path on the host to the deploy key's private key.    |
| `BACKUP_REPO`             | Yes      |                                                  | SSH URL of the backup repository.                    |
| `BACKUP_GIT_NAME`         | No       | `ssh-key-server-backup`                          | Author name of the backup commits.                   |
| `BACKUP_GIT_EMAIL`        | No       | `ssh-key-server-backup@users.noreply.github.com` | Author email of the backup commits.                  |
| `BACKUP_INTERVAL_SECONDS` | No       | `300`                                            | Seconds between backup rounds.                       |

- `install` refuses to run if `BACKUP_SSH_KEY` or `BACKUP_REPO` is missing or the key file does not exist, and adds the defaults for the optional settings to `.env`.
- `docker-compose.yml` requires `BACKUP_SSH_KEY` and `BACKUP_REPO` and will refuse to start otherwise.
- The key must be readable by UID `1654`, which the sidecar runs as: `install` sets its owner to UID/GID `1654` and its mode to `600`.
- The key is mounted read-only into the sidecar and is never copied, logged or built into the image.

### How it works

- The sidecar keeps its own clone of the backup repository in the `git-backup-work` volume, so the key server's data directory never contains any git metadata.
- The key data volume is mounted read-only into the sidecar, so it cannot modify the live key data.
- Every `BACKUP_INTERVAL_SECONDS` it copies the key data into its clone, commits only when something changed, rebases onto the remote and pushes. A round with no changes makes no commit and logs nothing.
- A failed rebase is aborted and retried in the next round.
- The backup repository's root holds the contents of `/data/keyserver` directly.

### Restore

- When `/data/keyserver` is empty, `install` clones the backup repository with the deploy key and copies its contents (without `.git`) into `/data/keyserver`, owned by UID/GID `1654`. It never touches a data directory that already contains files.
- To restore by hand, clone the backup repository into a temporary directory, copy its contents (without `.git`) into the empty `/data/keyserver`, and run `sudo chown -R 1654:1654 /data/keyserver`.

## Network

- HTTP is published on `${PORT:-8080}` and mapped to container port `8080` for HTTP/1.1 and HTTP/2 cleartext.
- HTTPS is published on `${HTTPS_PORT:-8081}` and mapped to container port `8081` for HTTP/1.1, HTTP/2, and HTTP/3.
- `install` opens the configured HTTP and HTTPS ports (including UDP on the HTTPS port for HTTP/3) to private networks (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fc00::/7`, `fe80::/10`) via `firewall-cmd` when `firewalld` is present.
- Watchtower is included to keep the deployment up-to-date.
