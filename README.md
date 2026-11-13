# Volunteer interest API

A Rails API with one Active Record model for volunteer interest submissions.
The source site's form fields could not be verified, so the endpoint accepts a
non-empty JSON object and stores its fields unchanged.

## Setup

Install Ruby 3.2 or newer and Bundler:

```sh
bundle install
bin/rails db:prepare
export API_KEY="$(ruby -rsecurerandom -e 'puts SecureRandom.hex(32)')"
bin/rails server -b 127.0.0.1 -p 9292
```

Save the generated key securely for the client and reuse it across restarts.
Changing `API_KEY` rotates the single shared key. Requests are rejected when
the configured key is missing or blank; there is no key management system.

## Submit

`POST /volunteer_submissions` accepts `application/json` and the key in
`X-API-Key`. Replace these example fields with the actual form fields:

```sh
curl -i http://127.0.0.1:9292/volunteer_submissions \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"Example Volunteer","email":"volunteer@example.org"}'
```

Success returns `201` and `{"id":1}`. An invalid or missing key returns `401`;
invalid JSON, an empty object, or a non-object body returns `400`. A body
larger than 65,536 bytes returns `413`, and an unsupported content type returns
`415`. No other application endpoints are provided.

## Database and deployment

Development and test use SQLite files under `storage/`. Production defaults to
`storage/production.sqlite3` and requires a durable volume. To use PostgreSQL,
set `DATABASE_URL` to a PostgreSQL connection URL, for example:

```sh
export DATABASE_URL="postgresql://localhost/volunteer_development"
bin/rails db:prepare
```

Use separate databases for each environment; tests may erase their database.
Submissions live in `volunteer_submissions` with a JSON `data` column and
standard Rails timestamps. The previous PStore file is not imported
automatically; preserve it and migrate any existing records before retiring it.

Protect database access and backups because submissions contain personal data.
Put the app behind HTTPS and a reverse proxy with an appropriate request-size
limit and rate limiting. Production assumes an SSL-terminating reverse proxy.
Do not embed the API key in public website JavaScript: have a trusted backend
submit the form instead. This API does not provide browser CORS or spam
protection. Avoid debug-level database logging when handling real submissions.

## Tests

```sh
bin/rails test
```
