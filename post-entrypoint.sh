#!/usr/bin/env bash

if [[ $INPUT_CLEANUP_THEME = 'true' ]]; then
  echo "Cleaning development theme..."
  shopify shopify theme delete -f -d
fi
