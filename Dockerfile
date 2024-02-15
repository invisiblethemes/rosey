FROM invisiblethemes/gha-shopify-cli:1.2.1
COPY entrypoint.sh /entrypoint.sh
COPY post-entrypoint.sh /post-entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
