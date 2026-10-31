#!/usr/bin/env bash
set -euo pipefail

VAULT_MOUNT="${DOCKER_VAULT_MOUNT:-secret}"
VAULT_PREFIX="${DOCKER_VAULT_PREFIX:-docker/profiles}"
PROFILE_DIR="$HOME/.docker-profiles"

cmd="${1:-}"
profile="${2:-}"

case "$cmd" in
  list)
    vault kv list \
      -mount="$VAULT_MOUNT" \
      "$VAULT_PREFIX"
    ;;

  use)
    # Must match the rule in docker-registry.sh
    if [[ ! "$profile" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo "Invalid profile name" >&2
      exit 1
    fi

    path="$VAULT_PREFIX/$profile"
    config="$PROFILE_DIR/$profile"

    registry=$(vault kv get \
      -mount="$VAULT_MOUNT" \
      -field=registry "$path")

    username=$(vault kv get \
      -mount="$VAULT_MOUNT" \
      -field=username "$path")

    # Read the active context before switching DOCKER_CONFIG
    # (Docker Desktop on macOS uses "desktop-linux", not the default socket)
    context=$(docker context show 2>/dev/null || echo default)

    mkdir -p "$config"
    chmod 700 "$PROFILE_DIR" "$config"

    # Share CLI plugins (compose, buildx) and contexts with ~/.docker.
    # Ubuntu apt installs plugins in /usr/libexec/docker/cli-plugins, which is found anyway.
    for item in cli-plugins contexts; do
      if [[ -d "$HOME/.docker/$item" && ! -e "$config/$item" ]]; then
        ln -s "$HOME/.docker/$item" "$config/$item"
      fi
    done

    if [[ ! -f "$config/config.json" && "$context" != "default" ]]; then
      printf '{"currentContext":"%s"}\n' "$context" > "$config/config.json"
    fi

    # Isolate each profile's Docker configuration.
    # No credsStore on purpose: keychain/pass are keyed by registry only,
    # so two profiles on the same registry would overwrite each other.
    export DOCKER_CONFIG="$config"

    # Retrieve token directly into docker login
    vault kv get \
      -mount="$VAULT_MOUNT" \
      -field=token "$path" |
      docker login "$registry" \
        --username "$username" \
        --password-stdin

    chmod 600 "$config/config.json"

    echo
    echo "Profile ready: $profile"
    echo "Run:"
    echo "export DOCKER_CONFIG=\"$config\""
    ;;

  current)
    echo "${DOCKER_CONFIG:-$HOME/.docker}"
    ;;

  *)
    {
      echo "Usage:"
      echo "  docker-profile list"
      echo "  docker-profile use <profile>"
      echo "  docker-profile current"
    } >&2
    exit 1
    ;;
esac
