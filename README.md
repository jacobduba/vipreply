# VIPReply

## Development Setup

### Prerequisites

- Git
- Docker (for PostgreSQL)
- Ruby 3.4.2

### Installation

1. Clone the repository and enter the directory:
    ```sh
    git clone git@github.com:jacobduba/vipreply.git
    cd vipreply
    ```

2. Install dependencies:
    ```sh
    bundle install
    ```

3. Set up the development key (get it from a team member):
    ```sh
    touch config/credentials/development.key
    chmod 600 config/credentials/development.key
    touch config/credentials/test.key
    chmod 600 config/credentials/test.key
    ```
   Then paste the master key for development into `config/credentials/development.key` and the master key for testing into `config/credentials/test.key`.

4. Start Postgres:
    ```sh
    docker-compose up
    ```

5. In another terminal, set up the database:
    ```sh
    bin/rails db:setup
    ```

### Running the Application

In three seperate terminals:

1. Start Postgres
    ```sh
    docker-compose up
    ```

2. Start the Rails server:
    ```sh
    bin/dev
    ```

Visit `http://localhost:3000` in your browser to see the application running.
Note that only localhost:3000 will work due to OAuth.

### VSCode Setup

Install **Ruby LSP:** [https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp](https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp)

Add this to your `settings.json` to use StandardRB as the formatter and linter:
```json
{
  "[ruby]": {
    "editor.defaultFormatter": "Shopify.ruby-lsp"
  },
  "rubyLsp.formatter": "standard",
  "rubyLsp.linters": [
    "standard"
  ]
}
```

### Zed Setup

If you're using Zed, you can configure Ruby LSP with StandardRB formating for Ruby and HTMLBeautifier linting for ERB with:

```sh
gem install ruby-lsp htmlbeautifier
```

```json
{
  "languages": {
    "ERB": {
      "tab_size": 2,
      "formatter": {
        "external": {
          "command": "ruby",
          "arguments": ["-S", "htmlbeautifier"]
        }
      }
    },
    "Ruby": {
      "language_servers": ["ruby-lsp", "!solargraph", "!rubocop"],
      "formatter": "language_server",
      "format_on_save": "on"
    }
  },
  "lsp": {
    "ruby-lsp": {
      "initialization_options": {
        "enabledFeatures": {
          "diagnostics": false,
          "formatting": true
        },
        "formatter": "standard"
      }
    }
  }
}
```

### Webhooks

#### Google Cloud Pub/Sub

I think we set up ngrok for this

#### Stripe Webhook

You can use Stripe CLI to test webhooks locally:

```sh
stripe listen --forward-to http://localhost:3000/webhooks/stripe
```

### Debugging Tips

If you need to delete and readd all messages for a Topic, in rails console run:

```ruby
Topic.find(42).debug_refresh # Replace 42 witht the ID of the topic
```

## Deployment

### GitHub Secrets Required
- `DIGITALOCEAN_ACCESS_TOKEN` - DO API token
- `RAILS_TEST_MASTER_KEY` - Test master key (Jacob knows the key)

### Deploy Process

1. Prepare app.yaml: Comment out RAILS_MASTER_KEY in .do/app.yaml (DigitalOcean doesn't accept encrypted values on first deploy, apparently)
2. Deploy: Push to main → GitHub Actions runs tests → Auto-deploys to DO
3. First deployment will fail (expected - missing master key)
4. Add secret in DO Dashboard:
  - Go to app settings → Environment Variables
  - Add RAILS_MASTER_KEY with the production key value (get from Jacob)
  - Save and let app restart
5. Get encrypted value:
  - Go to Settings → App Spec in DO dashboard
  - Find the RAILS_MASTER_KEY - it now shows as EV[...] (encrypted format)
  - Copy this entire encrypted value
6. Update app.yaml:
  - Uncomment RAILS_MASTER_KEY in .do/app.yaml
  - Replace with the encrypted value from step 5
  - Commit and push to redeploy with the encrypted secret
7. Configure DNS (after app is running):
  - In Cloudflare, create CNAMEs:
    - vipreply.ai → DO app URL
    - app.vipreply.ai → DO app URL
