#!/usr/bin/env bash

# Translate the GitHub action input arguments into environment variables for this scrip to use.
[[ -n "$INPUT_APP_PASSWORD" ]]      && export SHOP_APP_PASSWORD="$INPUT_APP_PASSWORD"
[[ -n "$INPUT_STORE" ]]             && export SHOP_STORE="$INPUT_STORE"
[[ -n "$INPUT_THEME_ROOT" ]]        && export THEME_ROOT="$INPUT_THEME_ROOT"

# Add global node bin to PATH (from the Dockerfile)
export PATH="$PATH:$npm_config_prefix/bin"

# Portable code below
set -eou pipefail

# Disable analytics
mkdir -p ~/.config/shopify && cat <<-YAML > ~/.config/shopify/config
[analytics]
enabled = false
YAML

# # Secret environment variable that turns shopify CLI into CI mode that accepts environment credentials
export CI=1
export SHOPIFY_SHOP="$SHOP_STORE"
export SHOPIFY_PASSWORD="$SHOP_APP_PASSWORD"

shopify login

if [[ $INPUT_CLEANUP_THEME = 'true' ]]; then
  echo "Cleaning development theme..."
  shopify theme delete -f -d
fi
