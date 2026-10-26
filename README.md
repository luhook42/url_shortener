# URL Shortener

A small URL shortener: a Sinatra API backed by Postgres, with Redis caching the redirects. A React dashboard in `dashboard/` lists, creates and edits links. Production runs with Docker Compose on a single GCP VM, which CI deploys to on every push to `main`.

## Layout

| Path | What it is |
| --- | --- |
| `app.rb`, `models/`, `config.ru` | The Sinatra app and the `Link` model |
| `config/` | Database settings and Puma settings (2 workers, 5–16 threads, port 4567) |
| `db/` | ActiveRecord migrations and schema |
| `test/` | Minitest + Rack::Test tests |
| `dashboard/` | React + TypeScript + Vite front end |
| `infra/` | Terraform for GCP, the VM's deploy/backup/health scripts, systemd timers (see [`infra/README.md`](infra/README.md)) |
| `.github/workflows/` | CI (test, build, deploy) and a manual rollback |
| `loadtest.js` | k6 load test |

## API

| Method | Path | What it does |
| --- | --- | --- |
| `GET` | `/health` | Returns `ok` |
| `GET` | `/links` | All links as JSON, newest first |
| `POST` | `/links` | Creates a link from form param `url`, returns `201` with the link |
| `PUT` | `/links/:code` | Changes the link's `url` and clears its cached redirect |
| `GET` | `/:code` | `302` redirect to the long URL, or `404` |

Short codes are 7 random alphanumeric characters. Redirects check Redis (`link:<code>`) first and fall back to Postgres, filling the cache on a miss.

```sh
curl -X POST -d url=https://example.com http://localhost:4567/links
curl -i http://localhost:4567/<code>
```

## Running locally

### With Docker Compose

```sh
cp .env.example .env          # set POSTGRES_PASSWORD and POSTGRES_DB
docker compose up -d --build
docker compose exec web bundle exec rake db:create db:migrate
```

The API is then on http://localhost:4567.

### Without Docker

Needs Ruby 4.0.7, plus Postgres and Redis running on localhost.

```sh
bundle install
bundle exec rake db:create db:migrate
bundle exec puma -C config/puma.rb
```

Set `DATABASE_URL` and `REDIS_URL` if they aren't on the defaults (`config/database.yml` and `redis://localhost:6379`).

### Dashboard

```sh
cd dashboard
npm install
npm run dev
```

It runs on http://localhost:5173 and talks to the API at `http://localhost:4567`. That origin is the only one allowed by CORS in `app.rb`.

## Tests

Tests need Postgres and Redis running locally. They use Redis database 1 and flush it on every test.

```sh
RACK_ENV=test bundle exec rake db:create db:migrate
bundle exec rake test
bundle exec rubocop
```

## Load testing

```sh
bundle exec rake db:seed_load_test   # makes 5,000 links and writes their codes to codes.json
k6 run loadtest.js
```

The test runs 50 virtual users for 30 seconds. Most requests are redirects, the first 5 codes get far more traffic than the rest (so the cache gets exercised), and about 1 in 1,000 requests creates a link.

## Deployment

Pushes to `main` run `.github/workflows/ci.yml`:

1. **test**: runs the test suite against Postgres 18 and Redis 7 service containers.
2. **build**: logs in to GCP through Workload Identity Federation, then builds the image and pushes it to Artifact Registry tagged with the commit SHA.
3. **deploy**: SSHes into the VM as `deploy <sha>` and then `health`. The SSH key is limited to `infra/bin/deploy.sh`, which checks out that commit, pulls the image for it and restarts the stack with `docker compose up -d --no-build`. `health` polls `/health` for up to 30 seconds.

To roll back, run the **Rollback** workflow from the Actions tab and give it the SHA of a version that worked. It runs the same deploy and health check for that commit.

On the VM, systemd timers run `infra/bin/site-health.sh` every 5 minutes and `infra/bin/backup-db.sh` every night at 03:00. The backup dumps Postgres to the GCS backup bucket and keeps 7 days of copies on the VM. Both scripts ping a heartbeat URL so a missed run gets noticed.

All GCP resources are managed in Terraform. See [`infra/README.md`](infra/README.md) for setup and things to watch for.
