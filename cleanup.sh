#!/usr/bin/env bash

# Portable code below
set -eou pipefail

shopify shopify theme delete -f -d
shopify logout
