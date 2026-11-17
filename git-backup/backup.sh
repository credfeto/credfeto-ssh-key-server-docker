#!/bin/sh

set -eu

die() {
    printf '\n\033[31m✗\033[0m %s\n' "$*" >&2
    exit 1
}

success() {
    printf '\n\033[32m✓\033[0m %s\n' "$*"
}

info() {
    printf '\n\033[32m→\033[0m %s\n' "$*"
}

require_settings() {
    [ -n "${REPO}" ] || die "BACKUP_REPO must be set"
    [ -d "${SOURCE_DIR}" ] || die "${SOURCE_DIR} does not exist"
    [ -r "${SSH_KEY_FILE}" ] || die "SSH key ${SSH_KEY_FILE} is missing or not readable"

    case "${INTERVAL_SECONDS}" in
        '' | *[!0-9]*) die "BACKUP_INTERVAL_SECONDS must be a positive integer" ;;
    esac

    [ "${INTERVAL_SECONDS}" -gt 0 ] || die "BACKUP_INTERVAL_SECONDS must be a positive integer"
}

configure_git() {
    # The quotes are literal on purpose: git runs GIT_SSH_COMMAND through a shell, which removes them.
    # shellcheck disable=SC2089
    GIT_SSH_COMMAND="ssh -i '${SSH_KEY_FILE}' -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile='${KNOWN_HOSTS_FILE}'"
    GIT_AUTHOR_NAME="${GIT_NAME}"
    GIT_AUTHOR_EMAIL="${GIT_EMAIL}"
    GIT_COMMITTER_NAME="${GIT_NAME}"
    GIT_COMMITTER_EMAIL="${GIT_EMAIL}"
    # shellcheck disable=SC2090
    export GIT_SSH_COMMAND GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
}

ensure_work_tree() {
    if [ -d "${WORK_DIR}/.git" ]; then
        return 0
    fi

    info "Cloning backup repository into ${WORK_DIR}"
    git -c init.defaultBranch=main clone -q "${REPO}" "${WORK_DIR}" || return 1
}

sync_source() {
    rsync -a --delete --exclude=/.git "${SOURCE_DIR}/" "${WORK_DIR}/" || return 1
}

commit_changes() {
    git -C "${WORK_DIR}" add -A || return 1

    changes="$(git -C "${WORK_DIR}" status --porcelain)" || return 1
    if [ -z "${changes}" ]; then
        return 0
    fi

    git -C "${WORK_DIR}" commit -q -m "Backup $(date -u '+%Y-%m-%dT%H:%M:%SZ')" || return 1
    info "Committed key data changes"
}

has_commits() {
    git -C "${WORK_DIR}" rev-parse -q --verify HEAD >/dev/null
}

has_upstream() {
    git -C "${WORK_DIR}" rev-parse -q --verify '@{u}' >/dev/null 2>&1
}

is_ahead_of_upstream() {
    ahead="$(git -C "${WORK_DIR}" rev-list --count '@{u}..HEAD')" || return 0
    [ "${ahead}" -gt 0 ]
}

has_unpushed_commits() {
    has_commits || return 1
    has_upstream || return 0
    is_ahead_of_upstream
}

rebase_onto_remote() {
    git -C "${WORK_DIR}" fetch -q origin || return 1

    # An empty remote has no upstream branch yet, so there is nothing to rebase onto.
    has_upstream || return 0

    if ! git -C "${WORK_DIR}" rebase -q '@{u}'; then
        git -C "${WORK_DIR}" rebase --abort >/dev/null 2>&1 || true
        info "Rebase onto the remote failed; aborted and retrying next round"
        return 1
    fi
}

publish_changes() {
    has_unpushed_commits || return 0

    rebase_onto_remote || return 1
    git -C "${WORK_DIR}" push -q -u origin HEAD || return 1
    success "Pushed key data backup"
}

backup_round() {
    ensure_work_tree || return 1

    if [ -e "${WORK_DIR}/.git/index.lock" ]; then
        info "Skipping backup round: ${WORK_DIR}/.git/index.lock exists"
        return 0
    fi

    sync_source || return 1
    commit_changes || return 1
    publish_changes || return 1
}

SOURCE_DIR="${BACKUP_SOURCE_DIR:-/data}"
WORK_DIR="${BACKUP_WORK_DIR:-/work/repo}"
SSH_KEY_FILE="${BACKUP_SSH_KEY_FILE:-/run/secrets/backup_ssh_key}"
KNOWN_HOSTS_FILE="${BACKUP_KNOWN_HOSTS:-/work/known_hosts}"
INTERVAL_SECONDS="${BACKUP_INTERVAL_SECONDS:-300}"
REPO="${BACKUP_REPO:-}"
GIT_NAME="${BACKUP_GIT_NAME:-ssh-key-server-backup}"
GIT_EMAIL="${BACKUP_GIT_EMAIL:-ssh-key-server-backup@users.noreply.github.com}"
RUN_ONCE="${BACKUP_ONCE:-0}"

require_settings
configure_git

trap 'exit 0' INT TERM

while :; do
    if ! backup_round; then
        [ "${RUN_ONCE}" = "1" ] && die "Backup round failed"
        info "Backup round failed; retrying in ${INTERVAL_SECONDS} seconds"
    fi

    [ "${RUN_ONCE}" = "1" ] && break

    # Sleeping in the background lets the TERM trap run immediately on docker stop.
    sleep "${INTERVAL_SECONDS}" &
    wait "$!"
done
