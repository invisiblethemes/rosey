#!/usr/bin/env bash

if [ $CLEANUP_THEME = 'true' ]; then
  shopify shopify theme delete -f -d
fi
