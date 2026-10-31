#!/usr/bin/env bash
set -euo pipefail

VAULT_MOUNT="${DOCKER_VAULT_MOUNT:-secret}"
VAULT_PREFIX="${DOCKER_VAULT_PREFIX:-docker/profiles}"
PROFILE="${1:-dockerhub-personal}"
USERNAME="${2:-}"
REGISTRY="${3:-docker.io}"

# Must match the rule in docker-profile.sh
if [[ ! "$PROFILE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Invalid profile name: $PROFILE (allowed: a-z A-Z 0-9 _ -)" >&2
  exit 1
fi

if [[ -z "$USERNAME" ]]; then
  read -rp "$REGISTRY username: " USERNAME
fi

read -rsp "$REGISTRY access token: " TOKEN
echo

if [[ -z "$USERNAME" || -z "$TOKEN" ]]; then
  echo "Username and token are required" >&2
  exit 1
fi

printf '%s' "$TOKEN" | vault kv put \
  -mount="$VAULT_MOUNT" \
  "$VAULT_PREFIX/$PROFILE" \
  registry="$REGISTRY" \
  username="$USERNAME" \
  token=-

echo "Saved profile: $PROFILE ($REGISTRY)"
