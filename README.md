# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

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
    ```
   Then paste the master key into `config/credentials/development.key` (never commit this file)

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
- `RAILS_TEST_MASTER_KEY` - Test master key

### DigitalOcean Setup
1. Create app from GitHub repo (main branch)
2. After creation, add in DO dashboard:
   - `RAILS_MASTER_KEY` - Production master key
3. In Cloudflare, point DNS to DO app:
   - `vipreply.ai` → CNAME to DO app URL
   - `app.vipreply.ai` → CNAME to DO app URL

### Deploy Process
- Push to `main` → GitHub Actions runs tests → Auto-deploys to DO
- Database migrations run automatically
- App spec: `.do/app.yaml`
