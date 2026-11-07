# URL Shortener

A small URL shortener: a Sinatra API backed by Postgres, with Redis caching the redirects. A React dashboard in `dashboard/` lists, creates and edits links. Production runs with Docker Compose on a single GCP VM, behind Caddy for HTTPS, and CI deploys to it on every push to `main`.

## Layout

| Path                             | What it is                                                                                                          |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `app.rb`, `models/`, `config.ru` | The Sinatra app and the `Link` model                                                                                |
| `config/`                        | Database settings and Puma settings (2 workers, 5–16 threads, port 4567)                                            |
| `db/`                            | ActiveRecord migrations and schema                                                                                  |
| `test/`                          | Minitest + Rack::Test tests                                                                                         |
| `dashboard/`                     | React + TypeScript + Vite front end                                                                                 |
| `Dockerfile`                     | Two-stage production image that runs Puma as a non-root `app` user                                                  |
| `docker-compose.yml`             | The `web`, `db` (Postgres 18), `redis` (Redis 7) and `caddy` services                                               |
| `Caddyfile`                      | Caddy config: serves `luke-links.com` over HTTPS and proxies to `web:4567`                                          |
| `infra/`                         | Terraform for GCP, the VM's deploy/backup/health scripts, systemd timers (see [`infra/README.md`](infra/README.md)) |
| `.github/workflows/`             | CI (test, dashboard, build, deploy) and a manual rollback                                                           |
| `loadtest.js`                    | k6 load test                                                                                                        |

## API

| Method | Path           | Auth | What it does                                                      |
| ------ | -------------- | ---- | ----------------------------------------------------------------- |
| `GET`  | `/health`      | no   | `ok` if Postgres and Redis both answer, otherwise `503 unhealthy` |
| `GET`  | `/links`       | yes  | All links as JSON, newest first                                   |
| `POST` | `/links`       | yes  | Creates a link from form param `url`, returns `201` with the link |
| `PUT`  | `/links/:code` | yes  | Changes the link's `url` and writes the new URL to the cache      |
| `GET`  | `/:code`       | no   | `302` redirect to the long URL, or `404`                          |

The `/links` routes need `Authorization: Bearer <API_TOKEN>` and return `401` without it. `POST` and `PUT` return `400` if `url` is missing or isn't an http(s) URL with a host.

Short codes are 7 random alphanumeric characters. Every redirect adds one to the link's `click_count`, whether or not it was cached. Redirects check Redis (`link:<code>`, 24-hour TTL) first and fall back to Postgres, filling the cache on a miss. If Redis is unreachable, redirects still work from Postgres alone.

```sh
curl -X POST -H "Authorization: Bearer $API_TOKEN" -d url=https://example.com http://localhost:4567/links
curl -i http://localhost:4567/<code>
```

## Running locally

### With Docker Compose

```sh
cp .env.example .env          # set POSTGRES_PASSWORD, POSTGRES_DB and API_TOKEN
docker compose up -d --build
docker compose exec web bundle exec rake db:create db:migrate
```

The API is then on http://localhost:4567. The `caddy` service starts too and will keep trying to get a certificate for `luke-links.com`; that's harmless locally, or run `docker compose up -d --build web` to skip it.

### Without Docker

Needs Ruby 4.0.8, plus Postgres and Redis running on localhost.

```sh
bundle install
bundle exec rake db:create db:migrate
API_TOKEN=change-me bundle exec puma -C config/puma.rb
```

Set `DATABASE_URL` and `REDIS_URL` if they aren't on the defaults (`config/database.yml` and `redis://localhost:6379`). Without `API_TOKEN`, every `/links` request is rejected.

### Dashboard

```sh
cd dashboard
echo "VITE_API_TOKEN=change-me" > .env.local   # the same value as the API's API_TOKEN
npm install
npm run dev
```

It runs on http://localhost:5173 and talks to the API at `http://localhost:4567` (set `VITE_API_URL` to change that). That origin is the only one allowed by CORS in `app.rb`.

The dashboard is for local `npm run dev` only. Vite puts `VITE_*` variables into the built JavaScript, so `npm run build` refuses to run while `VITE_API_TOKEN` is set.

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
k6 run -e API_TOKEN=change-me loadtest.js
```

The test runs 50 virtual users for 30 seconds. Most requests are redirects, the first 5 codes get far more traffic than the rest (so the cache gets exercised), and about 1 in 1,000 requests creates a link.

## Deployment

`.github/workflows/ci.yml` runs on every pull request and every push to `main`:

1. **test**: runs the test suite against Postgres 18 and Redis 7 service containers.
2. **dashboard**: lints and builds the dashboard.

Pushes to `main` then also run:

3. **build**: logs in to GCP through Workload Identity Federation, then builds the image and pushes it to Artifact Registry tagged with the commit SHA.
4. **deploy**: skips the deploy if a newer commit has landed on `main`. Otherwise it SSHes into the VM as `deploy <sha>` and then `health`. The SSH key is limited to `infra/bin/deploy.sh`, which:
   - pulls the image for that commit
   - runs migrations from the new image before changing the checkout, so a failed migration leaves the running version alone
   - checks out the commit and restarts the stack with `docker compose up -d --no-build`
   - recreates the `caddy` container if the `Caddyfile` changed, since the bind-mounted file isn't picked up otherwise
   - removes images older than 72 hours

   `health` polls `/health` for up to 30 seconds.

To roll back, run the **Rollback** workflow from the Actions tab and give it the SHA of a version that worked. It runs the same deploy and health check for that commit.

On the VM, systemd timers run `infra/bin/site-health.sh` every 5 minutes and `infra/bin/backup-db.sh` every night at 03:00. The backup dumps Postgres to the GCS backup bucket and keeps 7 days of copies on the VM. Both scripts ping a heartbeat URL so a missed run gets noticed.

All GCP resources are managed in Terraform, including an uptime check and alerts for site downtime and disk usage. See [`infra/README.md`](infra/README.md) for setup and things to watch for.
