#!/usr/bin/env bash

if [[ $CLEANUP_THEME = 'true' ]]; then
  echo "Cleaning development theme..."
  shopify shopify theme delete -f -d
fi
