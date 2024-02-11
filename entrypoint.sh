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
[[ -n "$INPUT_THEME_TOKEN" ]]          && export SHOP_THEME_TOKEN="$INPUT_THEME_TOKEN" || echo "theme_token not provided, proceeding without it."
[[ -n "$INPUT_STORE" ]]                && export SHOP_STORE="$INPUT_STORE" || echo "store not provided, proceeding without it."
[[ -n "$INPUT_THEME_ROOT" ]]           && export THEME_ROOT="$INPUT_THEME_ROOT"
[[ -n "$INPUT_THEME_COMMAND" ]]        && export THEME_COMMAND="$INPUT_THEME_COMMAND"
[[ -n "$INPUT_DEPLOY_LIST_JSON" ]]     && export DEPLOY_LIST_JSON="$INPUT_DEPLOY_LIST_JSON" || echo "deploy_list_json store not provided, proceeding without it."
[[ -n "$INPUT_DEPLOY_TEMPLATE_TOML" ]] && export DEPLOY_TEMPLATE_TOML="$INPUT_DEPLOY_TEMPLATE_TOML"  || echo "deploy_template_toml store not provided, proceeding without it."


# Add global node bin to PATH (from the Dockerfile)
export PATH="$PATH:$npm_config_prefix/bin"





 # END of GitHub Action Specific Code
####################################################################

# Portable code below
set -eou pipefail
deployment_executed=false

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


####################################################################
# Shopify single store CLI Deployment

# Only proceed with the following if STORE and THEME_TOKEN are provided
if [[ -n "$SHOP_STORE" && -n "$SHOP_THEME_TOKEN" ]]; then
  export SHOPIFY_CLI_TTY=0
  export SHOPIFY_CLI_STACKTRACE=1
  export SHOPIFY_FLAG_STORE="$SHOP_STORE"
  export SHOPIFY_CLI_THEME_TOKEN="$SHOP_THEME_TOKEN"

  exp_backoff() {
    local command="$1"
    local max_attempts="${2:-5}"
    local attempt=0
    local delay=1

    while [ "$attempt" -lt "$max_attempts" ]; do
      local_log="$(mktemp)"
      set -o pipefail

      # Run the command and store the output
      eval "$command" | tee $local_log

      local exit_code=$?

      # Check if the command contains anything about rate limiting
      if [ "$exit_code" -eq 1 ] && (cat "$local_log" | grep -q "429" || cat "$local_log" | grep -q "Reduce request rates"); then
        # If there's a rate limit error, increment the attempt counter and apply the delay
        attempt=$((attempt + 1))
        echo "Attempt $attempt of $max_attempts failed due to rate limit, retrying in $delay seconds..."
        sleep $delay

        # Calculate the next delay, doubling it each time
        delay=$((delay * 2))
      elif [ "$exit_code" -eq 1 ]; then
        # If the exit code is 1 (but not due to rate limiting), exit with error
        echo "not 429 error"
        exit 1
      else
        # If the exit code is not 1, break
        echo "success"
        break
      fi
    done

    if [ "$attempt" -eq "$max_attempts" ]; then
      echo "Maximum attempts reached, aborting." >&2
      exit 1
    fi
  }

  theme_root="${THEME_ROOT:-.}"
  theme_command="${THEME_COMMAND:-"push --development --json --path=$theme_root"}"
  theme_push_log="$(mktemp)"
  command="shopify theme $theme_command | tee $theme_push_log"

  log $command

  # Run command with exponential backoff in case we get rate-limited
  exp_backoff "$command"

  if [ $? -eq 1 ]; then
    echo "Error running theme command!" >&2
    exit 1
  fi

  # Extract JSON from shopify CLI output
  json_output="$(cat $theme_push_log | grep -o '{.*}')"

  preview_url="$(echo "$json_output" | tail -n 1 | jq -r '.theme.preview_url')"

  if [ -n "$preview_url" ]; then
    echo "Preview URL: $preview_url"
    echo "preview_url=$preview_url" >> $GITHUB_OUTPUT
  fi

  editor_url="$(echo "$json_output" | tail -n 1 | jq -r '.theme.editor_url')"

  if [ -n "$editor_url" ]; then
    echo "Editor URL: $editor_url"
    echo "editor_url=$editor_url" >> $GITHUB_OUTPUT
  fi

  preview_id="$(echo "$json_output" | tail -n 1 | jq -r '.theme.id')"

  if [ -n "$preview_id" ]; then
    echo "Theme ID: $preview_id"
    echo "theme_id=$preview_id" >> $GITHUB_OUTPUT
  fi

  deployment_executed=true
else
    echo "SHOP_STORE or SHOP_THEME_TOKEN is not set, skipping Shopify CLI commands."
fi


####################################################################
# TOML File Generation for Deployment

# Check if DEPLOY_LIST_JSON and DEPLOY_TEMPLATE_TOML are set
if [[ -n "$DEPLOY_LIST_JSON" && -n "$DEPLOY_TEMPLATE_TOML" ]]; then
    # Assuming DEPLOY_LIST_JSON and DEPLOY_TEMPLATE_TOML are passed as environment variables
    deployments_json="$DEPLOY_LIST_JSON"
    template="$DEPLOY_TEMPLATE_TOML"  # Fetch the template from an environment variable

    # Define the path for the generated TOML file
    output_path="./shopify.theme.toml"

    # Clear or create the TOML file
    echo "" > $output_path

    # Initialize an empty string to hold all environment arguments
    toml_store_list=""

    echo "${deployments_json}" | jq -c '.stores[]' | while read -r store; do
        url=$(echo $store | jq -r '.url')
        theme=$(echo $store | jq -r '.theme')
        secret=$(echo $store | jq -r '.secret')
        password="${!secret}" # Dereference the secret name to get its value from the environment

        # Replace placeholders in the template with actual values and append to the TOML file
        output=$(echo "$template" | sed "s/{{ url }}/$url/g" | sed "s/{{ theme }}/$theme/g" | sed "s/{{ password }}/$password/g")
        echo "$output" >> $output_path

        # Append the current store's formatted identifier to the toml_store_list string
        env_arg="--${url}-${theme}"
        toml_store_list="${toml_store_list} ${env_arg}"
    done

    # After processing all stores, output the toml_store_list to be used by subsequent steps/actions
    echo "toml_store_list=${toml_store_list}" >> $GITHUB_ENV
    deployment_executed=true
else
    echo "deploy_list_json or deploy_template_toml is not set, no toml created"
fi

####################################################################
# Final Check

if [ "$deployment_executed" = false ]; then
  echo -e "Error: Neither Shopify CLI deployment nor TOML file generation was executed."
  echo -e "If deploying multiple stores, ensure deploy_list_json is set with deploy_template_toml."
  echo -e "If deploying a single store, ensure shop_store is set with shop_theme_token."
  exit 
fi
