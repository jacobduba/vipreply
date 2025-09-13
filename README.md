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

### Linting

Run StandardRB to lint and auto-fix Ruby code:

```sh
bin/lint
```

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
    "HTML/ERB": {
      "tab_size": 2,
      "language_servers": ["tailwindcss-language-server", "..."],
      "formatter": {
        "external": {
          "command": "ruby",
          "arguments": ["-S", "htmlbeautifier"]
        }
      }
    },
    "Ruby": {
      "language_servers": [
        "ruby-lsp",
        "tailwindcss-language-server",
        "!solargraph",
        "!rubocop"
      ],
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
    },
    "tailwindcss-language-server": {
      "settings": {
        "includeLanguages": {
          "html/erb": "html",
          "ruby": "html"
        },
        "experimental": {
          "classRegex": ["\\bclass:\\s*['\"]([^'\"]*)['\"]"]
        }
      }
    }
  }
}
```

### Webhooks

#### Google Cloud Pub/Sub

The dashboard is (here)

Mock http request to test locally:

```

```

#### Stripe Webhook

Install the Stripe CLI: https://docs.stripe.com/stripe-cli

To test webhooks locally, run in a separate terminal:

```sh
bin/stripe
```

This will forward Stripe events to http://localhost:3000/webhooks/stripe

### Embeddings

VIPReply's embedding infrastructor makes iterating on embeddings locally easy as running a command... and delivers a pre-made process to upgrade embeddings in production.

#### Development

To develop embeddings locally, create a new generate_embeddings_sandbox function in message_embedding.rb.
You can copy generate_embeddings, rename to generate_embeddings_sandbox.
Then make edits you want in the generate_embeddings_sandbox.
NOTE: DO NOT EDIT GENERATE_EMBEDDINGS.

Reload your embeddings with
```bash
rails embeddings:reload
```
Rails with hotswap your embeddings locally.
This will break the embeddings momentarily... but not for long because dev shouldn't have too many embeddings

#### Production

Embeddings upgrades production uses an expand, backfill, contract pattern.
We create a new column (embedding_next), backfill it (by running a command), and then contract it (delete embeddings, rename embedding_nexts to embeddings)

First, create a new expand migration.
Replace N with what number is next.
To find N, just look for the newest ExpandEmbeddings migration and do N + 1.

```bash
rails generate migration ExpandEmbeddingsN
```

Copy the add_column line into change:

```ruby
class ExpandEmbeddingsN < ActiveRecord::Migration[8.0]
  def change
    # Paste this next line in.
    add_column :message_embeddings, :embedding_next, :vector, limit: 1024
  end
end
```

Second, rename your sandbox function from generate_embedding_sandbox to generate_embedding_next.

PUSH TO PROD

SSH into the production app and start the backfill.
```bash
bin/rails embeddings:upgrade
```

Wait for the backfill to complete.

CONTRACT

On dev create another migration:

```bash
rails generate migration ContractEmbeddingsN
```

Copy the remove_column and rename_column lines into change:

```ruby
class ContractEmbeddingsN < ActiveRecord::Migration[8.0]
  def change
    # Paste this these next two lines in.
    remove_column :message_embeddings, :embedding
    rename_column :message_embeddings, :embedding_next, :embedding
  end
end
```

Delete the generate_embedding function in message_embeddings.rb, and rename generate_embeddings_next to generate_embeddings.

PUSH TO PROD.

Congrats you have upgraded embeddings for VIPReply with 0 downtime for users.

### Debugging Tips

If you need to delete and readd all messages for a Topic, in rails console run:

```ruby
Topic.find(42).debug_refresh # Replace 42 witht the ID of the topic
```

## Deployment

### Deploy Process

1. Add required Github secrets
   - `DIGITALOCEAN_ACCESS_TOKEN` - DO API token
   - `RAILS_TEST_MASTER_KEY` - Test master key
1. Prepare app.yaml: Comment out RAILS_MASTER_KEY in .do/app.yaml (DigitalOcean doesn't accept encrypted values on first deploy, apparently)
2. Deploy: Push to main → GitHub Actions runs tests → Auto-deploys to DO
3. First deployment will fail (expected - missing master key)
4. Add secret in DO Dashboard:
   - Go to app settings → Environment Variables
   - Add RAILS_MASTER_KEY with the production key value
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

### Security Configuration Audit Points
To verify integrity of security-relevant configurations:
- **DigitalOcean**: Account → Security → Audit Logs
- **GitHub**: Settings → Security log
- **Cloudflare**: Account → Audit Log
- **Google Cloud**: Console → Activity logs
- **Stripe**: Dashboard → Logs
