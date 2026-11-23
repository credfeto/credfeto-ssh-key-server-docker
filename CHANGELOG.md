# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Please ADD ALL Changes to the UNRELEASED SECTION and not a specific release
-->

## [Unreleased]
### Security
- Firewall: the reverse proxies' Servers VLAN addresses (`192.168.150.250`, `192.168.150.251`, `2a02:8010:61d5:150::250`, `2a02:8010:61d5:150::251`) are no longer allowed; proxy-01/proxy-02 are only reached on their DMZ VLAN addresses
- Firewall: the reverse proxies' DMZ VLAN addresses (`192.168.140.250`, `192.168.140.251`, `2a02:8010:61d5:140::250`, `2a02:8010:61d5:140::251`) are allowed alongside their Servers VLAN addresses, so proxy-01/proxy-02 can move to the DMZ one at a time without losing access
- Host firewall lockdown for ingress and egress (`firewall/configure`, run by `install`): an nftables table lets only the reverse proxies reach the published key server ports, and firewalld policies limit what the host and the containers may connect to, with CDN-fronted destinations kept in ipsets refreshed every 10 minutes. `keys-firewall-sync.timer` re-applies it when the firewall config changes, and the daily `Repo: Update egress ranges` workflow refreshes the GitHub and Cloudflare ranges. Observation mode (log unmatched traffic, drop nothing) until `KEYS_FIREWALL_ENFORCE=true`
### Added
- Git backup sidecar that backs up the key data to a GitHub repository using a deploy key (#27)
- Added add-key, delete-key and list-keys scripts to add, delete and list the keys held by the key server, running the server's admin CLI in the docker compose container, with README documentation (#29)
### Fixed
- Firewall: resolved destinations (Docker Hub, ghcr.io and the other CDN-fronted names) stay allowed for 7 days after they were last seen instead of only the latest DNS answer, so direct Docker Hub pulls when the docker-cache mirror is down are not dropped because the registry answered with a different part of its address pool
### Changed
- The git-backup image is built and published to ghcr.io/credfeto/ssh-key-server-git-backup by a workflow whenever git-backup/ changes, and docker-compose pulls it from there instead of building it locally, so watchtower can update it
- The host egress firewall is now one nftables table (`inet key_egress`) loaded atomically by `firewall/egress`, instead of firewalld policies and ipsets: the 10-minute refresh reloaded firewalld, and a firewalld killed mid-reload (by the OOM killer) left its block-everything table in place and cut the host off. `firewall/configure` removes the old policies and ipsets with one last reload
### Deprecated
### Removed
- Removed unused .NET src/global.json and template solution src/Credfeto.Template.slnx (and its DotSettings)
### Deployment Changes
- .env now requires BACKUP_SSH_KEY (path to a deploy key with write access) and BACKUP_REPO (SSH URL of a private backup repository); install and docker compose refuse to run without them, and install adds defaults for BACKUP_GIT_NAME, BACKUP_GIT_EMAIL and BACKUP_INTERVAL_SECONDS (#27)

<!--
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->

## [0.0.7] - 2026-11-04
### Changed
- SDK - Updated DotNet SDK to 11.0.100-rc.3.26522.148
### Removed
- Removed src/FunFair.props, which is not permitted outside funfair-tech

## [0.0.6] - 2026-10-26
### Changed
- SDK - Updated DotNet SDK to 10.0.403

## [0.0.5] - 2026-10-15
### Changed
- SDK - Updated DotNet SDK to 10.0.402

## [0.0.4] - 2026-09-17
### Changed
- SDK - Updated DotNet SDK to 10.0.401

## [0.0.3] - 2026-08-20
### Added
- install now opens the configured HTTP/HTTPS ports (including UDP for HTTP/3) to private networks via firewalld, so the firewall no longer needs configuring by hand
- install now generates a .env with a random CHALLENGE_HMAC_SECRET when missing, and install/update refuse to run without it, so the key server's Challenge:HmacSecret is always provisioned before the containers start
### Changed
- SDK - Updated DotNet SDK to 10.0.400

## [0.0.2] - 2026-07-16
### Changed
- SDK - Updated DotNet SDK to 10.0.302

## [0.0.1] - 2026-06-11
### Added
- Added a docker compose deployment for the SSH key server with watchtower plus `install`, `update`, and `reset` helper scripts that manage the external `/data/keyserver` bind-backed volume and a local self-signed TLS certificate.
### Fixed
- Corrected broken cross-reference in github-workflows.instructions.md — anchor #visual-indicators updated to #output-helpers to match actual section name in shell-scripts.instructions.md
- shell.firewall.examples.md open_port_for_private_networks no longer calls firewall-cmd --reload internally; added explicit caller-reload rule to shell.firewall.instructions.md
### Changed
- die() must output to stderr so error messages are not swallowed by stdout pipelines
- SDK - Updated DotNet SDK to 10.0.301

## [0.0.0] - Project created