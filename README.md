# Rosey 🤖

Rosey the theme deploy bot

Used to deploy themes to QA stores via GitHub Actions

Uses [invisiblethemes/docker-gha-shopify-cli](https://github.com/invisiblethemes/docker-gha-shopify-cli) as a base Docker image


## Features

- **Multiple Store Deployments**: Deploy themes to multiple Shopify stores by specifying configurations in a JSON file.
- **Customizable TOML Templates**: Use TOML templates to define environment-specific configurations, making it easy to manage different settings across stores.
- **Secure Secret Management**: Leverages GitHub Secrets for secure handling of sensitive information like Shopify API access tokens and passwords.
- **Post-Action Cleanup**: Optionally, delete the development theme after deployment to keep your Shopify account clean and organized.

## Inputs

| Name                | Description                                                                                   | Required |
|---------------------|-----------------------------------------------------------------------------------------------|----------|
| `theme_token`       | Shopify theme access token.                                                                   | Yes      |
| `store`             | The `<domain>.myshopify.com` URL of the store.                                                | Yes      |
| `theme_root`        | The root folder for the theme assets that will be uploaded. Defaults to `.`.                  | No       |
| `theme_command`     | Optional command to run instead of `push --development`.                                      | No       |
| `deploy_list_json`  | JSON string containing store, themes, and GitHub secrets for deploy passwords.                | No       |
| `deploy_template_toml` | TOML template string for deployment environments.                                          | No       |
| `cleanup_theme`     | Whether or not to delete the development theme in a post-action script. Defaults to `false`.  | No       |

## Outputs

| Name          | Description                              |
|---------------|------------------------------------------|
| `preview_url` | The preview URL for the deployed theme.  |
| `editor_url`  | The editor URL for the deployed theme.   |
| `theme_id`    | The ID for the deployed theme.           |

## Usage

1. **Prepare Your Secrets**

   Before using this action, ensure you have set the following secrets in your GitHub repository:

   - Shopify API access tokens and passwords for each store.
   - The JSON configuration (`DEPLOY_LIST_JSON`) that specifies the stores, themes, and corresponding secrets for deployment.
   - The TOML template (`DEPLOY_TEMPLATE_TOML`) for environment configuration.

2. **Configure the GitHub Action**

   Add the following step to your GitHub Actions workflow file (`.github/workflows/deploy.yml`):

```yaml
- name: Deploy Shopify Theme
  uses: your-github-username/shopify-theme-deploy-action@v1
  with:
    theme_token: ${{ secrets.SHOP_TOKEN }}
    store: 'example-store.myshopify.com'
    deploy_list_json: ${{ secrets.DEPLOY_LIST_JSON }}
    deploy_template_toml: ${{ secrets.DEPLOY_TEMPLATE_TOML }}
```


## Customize JSON and TOML Templates

Adjust the `DEPLOY_LIST_JSON` and `DEPLOY_TEMPLATE_TOML` secrets to match your deployment requirements. Refer to the "Configuration" section below for details on formatting these templates.

## Configuration

### JSON Template (`DEPLOY_LIST_JSON`)

This JSON structure specifies which stores to deploy to, the theme IDs, and the secrets containing deployment passwords:

```json
{
  "stores": [
    {"url": "example-store", "theme": "123456789012", "secret": "EXAMPLE_STORE_PASSWORD"}
    {"url": "example-store", "theme": "987654321000", "secret": "EXAMPLE_STORE_PASSWORD"}
    {"url": "another-store", "theme": "180055519191", "secret": "ANOTHER_STORE_PASSWORD"}
    // Add additional stores as needed
  ]
}
```

### TOML Template (DEPLOY_TEMPLATE_TOML)
```toml
[environments."{{ url }}-{{ theme }}"]
theme = "{{ theme }}"
password = "{{ password }}"
store = "{{ url }}.myshopify.com"
ignore = ["config/settings_data.json","templates/*.json","sections/*.json","templates/*.*.json","templates/customers/.*.json"]
```
Replace placeholders ({{ url }}, {{ theme }}, and {{ password }}) with actual values during the deployment process.


## Using `toml_store_list` in Subsequent Steps

The `toml_store_list` environment variable is dynamically generated during the action execution. It contains a space-separated list of CLI arguments representing each store and theme configuration specified in the `DEPLOY_LIST_JSON`. This list is formatted to be directly usable with Shopify CLI commands or custom deployment scripts.

### How `toml_store_list` is Generated

`toml_store_list` is compiled by processing the `DEPLOY_LIST_JSON` input, which outlines the deployment targets. Each target's `url` and `theme` identifiers are concatenated with a leading `--`, forming arguments like `--example-store-123456789012`. These arguments are then combined into a single string, which is set as the `toml_store_list` environment variable for use in subsequent workflow steps.

### Making `toml_store_list` Available

The variable is made available to subsequent steps by echoing it with the `GITHUB_ENV` syntax at the end of the deployment script:

```bash
echo "toml_store_list=${toml_store_list}" >> $GITHUB_ENV
```

This command appends `toml_store_list` to the $GITHUB_ENV file, exporting it as an environment variable for the remainder of the job.

Utilizing `toml_store_list` in Subsequent Actions
Once `toml_store_list` has been set, it can be utilized in any subsequent step within the same job. Here's an example of how to use `toml_store_list` with a hypothetical yarn deploy command:

```yaml
- name: Deploy with Yarn
  run: yarn deploy ${{ env.toml_store_list }}
```
This step runs `yarn deploy`, passing in the `toml_store_list` variable as arguments to the command. This enables the deployment script to operate with the context of each specified store and theme, facilitating a multi-target deployment process.
