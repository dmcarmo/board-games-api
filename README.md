# README

## Development

* rails db:create db:migrate
* rails s
* bundle exec good_job start

## Production

* secrets are set in `credentials.yml.enc` so we need to pass `RAILS_MASTER_KEY` as a env variable with the value from the local `master.key`
