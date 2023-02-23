#!/usr/bin/env bash

####################################################################
# START of GitHub Action specific code

# This script assumes that node, curl, sudo, python and jq are installed.

# If you want to run this script in a non-GitHub Action environment,
# all you'd need to do is set the following environment variables and
# delete the code below. Everything else is platform independent.
#
# Here, we're translating the GitHub action input arguments into environment variables
# for this scrip to use.
[[ -n "$INPUT_THEME_TOKEN" ]]       && export SHOP_THEME_TOKEN="$INPUT_THEME_TOKEN"
[[ -n "$INPUT_STORE" ]]             && export SHOP_STORE="$INPUT_STORE"
[[ -n "$INPUT_THEME_ROOT" ]]        && export THEME_ROOT="$INPUT_THEME_ROOT"
[[ -n "$INPUT_THEME_COMMAND" ]]     && export THEME_COMMAND="$INPUT_THEME_COMMAND"

# Add global node bin to PATH (from the Dockerfile)
export PATH="$PATH:$npm_config_prefix/bin"

# END of GitHub Action Specific Code
####################################################################

# Portable code below
set -eou pipefail

log() {
  echo "$@" 1>&2
}

step() {
  cat <<-EOF 1>&2
	==============================
	$1
	EOF
}

is_installed() {
  # This works with scripts and programs. For more info, check
  # http://goo.gl/B9683D
  type $1 &> /dev/null 2>&1
}

cleanup() {
  if [[ -n "${theme+x}" ]]; then
    step "Disposing development theme"
    shopify shopify theme delete -f -d
  fi

  return $1
}

trap 'cleanup $?' EXIT

if ! is_installed shopify; then
  echo "shopify cli is not installed" >&2
  exit 1
fi

step "Configuring shopify CLI"

# Disable analytics
mkdir -p ~/.config/shopify && cat <<-YAML > ~/.config/shopify/config
[analytics]
enabled = false
YAML

# Secret environment variable that turns shopify CLI into CI mode that accepts environment credentials
export SHOPIFY_CLI_TTY=0
export SHOPIFY_FLAG_STORE="$SHOP_STORE"
export SHOPIFY_CLI_THEME_TOKEN="$SHOP_THEME_TOKEN"

theme_root="${THEME_ROOT:-.}"
theme_command="${THEME_COMMAND:-"push --development --json --path=$theme_root"}"
theme_push_log="$(mktemp)"

# command="shopify theme $theme_command | tee $theme_push_log"
# command="shopify theme $theme_command"
command="trap 'echo \"Caught exit 1\"' EXIT; exit 1"

log $command

eval $command

# # Extract JSON from shopify CLI output
# json_output="$(cat $theme_push_log | grep -o '{.*}')"

# if [ -z "$json_output" ]; then
#   exit 0
# fi

# preview_url="$(echo "$json_output" | tail -n 1 | jq -r '.theme.preview_url')"

# if [ -n "$preview_url" ]; then
#   echo "Preview URL: $preview_url"
#   echo "preview_url=$preview_url" >> $GITHUB_OUTPUT
# fi

# editor_url="$(echo "$json_output" | tail -n 1 | jq -r '.theme.editor_url')"

# if [ -n "$editor_url" ]; then
#   echo "Editor URL: $editor_url"
#   echo "editor_url=$editor_url" >> $GITHUB_OUTPUT
# fi

# preview_id="$(echo "$json_output" | tail -n 1 | jq -r '.theme.id')"

# if [ -n "$preview_id" ]; then
#   echo "Theme ID: $preview_id"
#   echo "theme_id=$preview_id" >> $GITHUB_OUTPUT
# fi
