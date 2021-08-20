FROM anark6/gha-shopify-cli:1.0.0
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
