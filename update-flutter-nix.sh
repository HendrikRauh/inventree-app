#!/usr/bin/env bash

# This script adjusts flake.nix to use the flutter version
# pinned in .fvmrc. It fetches the appropriate commit hash.

set -euo pipefail

for cmd in jq curl sed nix; do
  command -v $cmd >/dev/null 2>&1 || { echo "Error: $cmd is not installed!"; exit 1; }
done

if [ ! -f .fvmrc ]; then
  echo ".fvmrc file not found!"
  exit 1
fi

FLUTTER_VERSION=$(jq -r .flutter .fvmrc)
echo "Requested Flutter version: $FLUTTER_VERSION"

API_URL="https://search.devbox.sh/v2/pkg?name=flutter"
RELEASES_JSON=$(curl -s "$API_URL")

ALL_VERSIONS=$(echo "$RELEASES_JSON" | jq -r '.releases[].version' | sort -V)

FOUND_VERSION=$(echo "$ALL_VERSIONS" | awk -v v="$FLUTTER_VERSION" '$0 >= v { print; exit }')

if [ -z "$FOUND_VERSION" ]; then
  echo "Error: No matching Flutter version found."
  exit 1
fi

if [ "$FOUND_VERSION" != "$FLUTTER_VERSION" ]; then
  echo "Note: Exact version not found, using version $FOUND_VERSION instead."
fi

COMMIT=$(echo "$RELEASES_JSON" | jq -r --arg v "$FOUND_VERSION" '.releases[] | select(.version==$v) | .platforms[] | select(.system=="x86_64-linux") | .commit_hash' | head -n 1)

if [ -z "$COMMIT" ] || [ "$COMMIT" == "null" ]; then
  echo "Error: No commit hash found for version $FOUND_VERSION and platform x86_64-linux."
  exit 1
fi

echo "Found commit: $COMMIT (Version: $FOUND_VERSION)"


sed -i.bak "s|nixpkgs-flutter.url = \"github:NixOS/nixpkgs/[a-f0-9]*\";|nixpkgs-flutter.url = \"github:NixOS/nixpkgs/$COMMIT\";|" flake.nix

nix flake update nixpkgs-flutter

if command -v direnv >/dev/null 2>&1; then
  direnv reload
fi

echo "Success! flake.nix now uses the commit for Flutter $FLUTTER_VERSION (or higher)."
