
#!/usr/bin/env bash

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

MANAGED_BY="conflux"
CONTAINER_PREFIX="conflux-"

# Override with CONFLUX_IMAGE.
CONFLUX_IMAGE="${CONFLUX_IMAGE:-alpine/socat:latest}"

info() {
    printf '[INFO] %s\n' "$*"
}

success() {
    printf '[OK] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

container_name_for() {
    printf '%s%s' "$CONTAINER_PREFIX" "$1"
}
