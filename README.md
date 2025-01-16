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

### Installation

1. Install Ruby 3.3.6 using your preferred method ([rbenv recommended](https://rbenv.org/):
    ```sh
    rbenv install 3.3.6
    rbenv global 3.3.6
    ```

2. Clone the repository and enter the directory:
    ```sh
    git clone git@github.com:jacobduba/emailthingy.git
    cd emailthingy
    ```

3. Install dependencies:
    ```sh
    bundle install
    ```

4. Set up the development key (get it from a team member):
    ```sh
    touch config/credentials/development.key
    chmod 600 config/credentials/development.key # Set correct permissions
    ```
   Then paste the master key into `config/credentials/development.key` (never commit this file)

5. Start Postgres:
    ```sh
    docker-compose up
    ```

6. In another terminal, set up the database:
    ```sh
    bin/rails db:setup
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
    "HTML": {
      "tab_size": 2
    },
    "ERB": {
      "format_on_save": "on",
      "tab_size": 2,
      "formatter": {
        "external": {
          "command": "htmlbeautifier",
          "arguments": []
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
