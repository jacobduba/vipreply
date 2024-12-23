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

4. Set up the master key (get it from a team member):
    ```sh
    touch config/master.key
    chmod 600 config/master.key  # Set correct permissions
    ```
   Then paste the master key into `config/master.key` (never commit this file)

5. Start Postgres:
    ```sh
    docker-compose up
    ```

6. In another terminal, set up the database:
    ```sh
    bin/rails db:setup
    ```

### Running the Application

In three seperate terminals:

1. Start Postgres
    ```sh
    docker-compose up
    ```
2. Start TailwindCSS:
    ```sh
    bin/rails tailwindcss:watch
    ```

3. Start the Rails server:
    ```sh
    bin/rails server
    ```

Visit `http://localhost:3000` in your browser to see the application running.