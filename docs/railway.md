# Railway Deployment

This app is configured for Railway's Dockerfile deploy path. The checked-in
`railway.json` tells Railway to build from `Dockerfile`, run `bin/rails
db:prepare` before deploys, and health-check `/up`.

## Create the Railway project

1. Create a new Railway project from the GitHub repo.
2. Add a PostgreSQL service to the Railway project.
3. On the Rails app service, set these variables:

```text
RAILS_ENV=production
DATABASE_URL=${{Postgres.DATABASE_URL}}
SECRET_KEY_BASE=<output from bin/rails secret>
WEB_CONCURRENCY=1
RAILS_MAX_THREADS=5
ANTHROPIC_API_KEY=<optional, enables LLM search parsing and news filtering>
ADMIN_PASSWORD=<optional, overrides the default admin password>
```

`RAILS_MASTER_KEY` is not required unless production credentials are added and
`config.require_master_key` is enabled later.

`WEB_CONCURRENCY` controls the number of Puma worker processes, and
`RAILS_MAX_THREADS` controls the number of request threads and Active Record
connections per worker. The maximum database connection budget is
`WEB_CONCURRENCY * RAILS_MAX_THREADS`, so the default Railway setup above uses
up to 5 application database connections.

## First deploy

After the GitHub repo is connected, Railway should detect `railway.json`, build
with the Dockerfile, run migrations through the pre-deploy command, and start the
Rails server on Railway's assigned `PORT`.

Generate a Railway domain from the service Networking tab, then open `/up` to
confirm the deployed app is healthy.

Railway references:

- Rails guide: <https://docs.railway.com/guides/rails>
- Config as code: <https://docs.railway.com/config-as-code/reference>
