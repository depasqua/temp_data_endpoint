# Volunteer interest API

A small Ruby API with one model for storing volunteer interest submissions.
The source site's form fields could not be verified, so the endpoint accepts a
non-empty JSON object and stores its fields unchanged rather than assuming a
specific form schema.

## Run

Install Ruby and Bundler, then:

```sh
bundle install
export API_KEY="$(ruby -rsecurerandom -e 'puts SecureRandom.hex(32)')"
bundle exec ruby app.rb
```

Save the generated key securely for the client and reuse it across restarts.
Changing `API_KEY` and restarting rotates the single shared key; there is no
per-client key management. The server refuses to start without a nonblank key.
It listens on `127.0.0.1:9292` by default; `HOST` and `PORT` can override this.

## Submit

`POST /volunteer_submissions` accepts `application/json`, a `Content-Length`,
and the key in `X-API-Key`. Replace the example fields with the actual form
fields. The maximum body size is 65,536 bytes.

```sh
curl -i http://127.0.0.1:9292/volunteer_submissions \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"Example Volunteer","email":"volunteer@example.org"}'
```

A successful request returns `201` and `{"id":"..."}`. Missing or incorrect
keys return `401`; invalid JSON or an empty/non-object body returns `400`.
Other responses include `405` for an unsupported method, `411` for a missing
length or chunked body, `413` for an oversized body, and `415` for an
unsupported content type.

## Storage and deployment

Submissions and UTC creation timestamps are stored in the local PStore file
`data/submissions.pstore`; `DATA_PATH` can select another location. Use a
durable, access-controlled volume and secure backups: this file contains
personal information. Only load a trusted PStore file, as PStore uses Ruby
serialization. This simple single-host store is not intended for multiple
servers or large datasets.

For example, an administrator with access to the file can inspect records with:

```sh
bundle exec ruby -rpstore -e 's = PStore.new(ARGV.fetch(0)); s.transaction(true) { s.roots.each { |id| p [id, s[id]] } }' data/submissions.pstore
```

The server speaks plain HTTP. For remote use, put it behind HTTPS and restrict
access to the service and its storage. Do not embed the API key in public
website JavaScript: have a trusted backend submit the form instead. This API
does not provide browser CORS support, rate limiting, or spam protection.

## Tests

```sh
bundle exec ruby -Itest test/app_test.rb
```