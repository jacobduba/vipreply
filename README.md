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

5. Set up the database:
    ```sh
    bin/rails db:setup
    ```

### Running the Application

Start the Rails server:
```sh
bin/rails server
```

Start TailwindCSS:
```sh
bin/rails tailwindcss:watch
```

Visit `http://localhost:3000` in your browser to see the application running.