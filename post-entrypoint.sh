#!/usr/bin/env bash

####################################################################
# START of GitHub Action specific code

# This script assumes that node, curl, sudo, python and jq are installed.

# If you want to run this script in a non-GitHub Action environment,
# all you'd need to do is set the following environment variables and
# delete the code below. Everything else is platform independent.
#
# Here, we're translating the GitHub action input arguments into environment variables
# for this script to use.
[[ -n "$INPUT_APP_PASSWORD" ]]      && export SHOP_APP_PASSWORD="$INPUT_APP_PASSWORD"
[[ -n "$INPUT_STORE" ]]             && export SHOP_STORE="$INPUT_STORE"
[[ -n "$INPUT_THEME_ROOT" ]]        && export THEME_ROOT="$INPUT_THEME_ROOT"
[[ -n "$INPUT_CLEANUP_THEME" ]]     && export SHOP_CLEANUP_THEME="$INPUT_CLEANUP_THEME"

# Add global node bin to PATH (from the Dockerfile)
export PATH="$PATH:$npm_config_prefix/bin"

# END of GitHub Action Specific Code
####################################################################

# Portable code below
set -eou pipefail

if [ $CLEANUP_THEME == 'true' ]; then

step "Deleting development theme"

# Disable analytics
mkdir -p ~/.config/shopify && cat <<-YAML > ~/.config/shopify/config
[analytics]
enabled = false
YAML

# Secret environment variable that turns shopify CLI into CI mode that accepts environment credentials
export CI=1
export SHOPIFY_SHOP="$SHOP_STORE"
export SHOPIFY_PASSWORD="$SHOP_APP_PASSWORD"

shopify shopify theme delete -f -d

fi
