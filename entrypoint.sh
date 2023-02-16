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
[[ -n "$INPUT_THEME_TOKEN" ]]      && export SHOP_THEME_TOKEN="$INPUT_THEME_TOKEN"
[[ -n "$INPUT_STORE" ]]            && export SHOP_STORE="$INPUT_STORE"
[[ -n "$INPUT_THEME_ROOT" ]]       && export THEME_ROOT="$INPUT_THEME_ROOT"
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
    shopify logout
  fi

  if [[ -f "lighthouserc.yml" ]]; then
    rm "lighthouserc.yml"
  fi

  if [[ -f "setPreviewCookies.js" ]]; then
    rm "setPreviewCookies.js"
  fi

  return $1
}

trap 'cleanup $?' EXIT

step "Configuring shopify CLI"

# Disable analytics
mkdir -p ~/.config/shopify && cat <<-YAML > ~/.config/shopify/config
[analytics]
enabled = false
YAML

# Secret environment variable that turns shopify CLI into CI mode that accepts environment credentials
export CI=1
export SHOPIFY_CLI_TTY=0
export SHOPIFY_FLAG_STORE="$SHOP_STORE"
export SHOPIFY_CLI_THEME_TOKEN="$SHOP_THEME_TOKEN"

theme_root="${THEME_ROOT:-.}"

step "Creating development theme"
theme_push_log="$(mktemp)"

if [[ -n "${THEME_COMMAND}" ]]; then
  step "Running custom theme command 'shopify ${THEME_COMMAND}'"
  shopify theme ${THEME_COMMAND} --path=$theme_root > "$theme_push_log" && cat "$theme_push_log"
else
  step "Running 'shopify theme push'"
  shopify theme push --development --path=$theme_root > "$theme_push_log" && cat "$theme_push_log"
fi

echo $theme_push_log

preview_url="$(cat "$theme_push_log" | awk '/View your theme:/ { getline; print }'"
editor_url="$(cat "$theme_push_log" | awk '/Customize this theme in the Theme Editor:/ { getline; print }'"

# TODO
# preview_id=".."

echo "preview_url=$preview_url" >> $GITHUB_OUTPUT
echo "editor_url=$editor_url" >> $GITHUB_OUTPUT
# echo "theme_id=$preview_id" >> $GITHUB_OUTPUT
