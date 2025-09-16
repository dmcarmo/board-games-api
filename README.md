# README

## Development

* rails db:create db:migrate
* rails s
* bundle exec good_job start

## Production

* secrets are set in `credentials.yml.enc` so we need to pass `RAILS_MASTER_KEY` as a env variable with the value from the local `master.key`

## API Documentation

### Base URL

* `https://board-games-api.boardgametools.net/api`

### Endpoints

#### Authentication

* Create authentication token
  * Request
    * POST `/api-keys`
    * Authorization header using HTTP Basic Authentication (email:password)
  * Response
    * `{"id":1,"bearer_type":"User","bearer_token":"BEARER-TOKEN"}`
* List existing tokens
  * Request
    * GET `/api-keys`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 1, "bearer_type": "User", "bearer_id": 1, "token_digest": "XXXXX", "created_at": 2025-05-12T18:01:17.306Z", "updated_at": "2025-05-12T18:01:17.306Z", "revoked_at": null}, ...]`
* Show a token
  * Request
    * GET `/api-keys/1`
    * Authorization header using Bearer Token
  * Response
    * `{"id": 1, "bearer_type": "User", "revoked_at": null}`
* Delete a token
  * Request
    * DELETE `/api-keys/1`
    * Authorization header using Bearer Token
  * Response
    * `{"id": 1, "bearer_type": "User", "revoked_at": 2025-05-12T18:11:23.105Z}`

#### List Games

* List base games and expansions
  * Request
    * GET `/games`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text"}, ...]`
* List only base games
  * Request
    * GET `/games?filter=base_games`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text"}, ...]`
* List only expansions
  * Request
    * GET `/games?filter=expansions`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text"}, ...]`

#### Search Games

* Search
  * by default the response only returns name, bgg_id, year_published and image_url
  * to display the full response add `extended=true` to the query params
* Search - partial match
  * Request
    * GET `/games?name=stop`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text"}, ...]`
* Search - exact match
  * Request
    * GET `/games?name=Can't Stop&exact=true`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text"}, ...]`
* Search - by bgg_id
  * Request
    * GET `/games?bgg_id=41`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text"}, ...]`

#### Show Game

* Show
  * Request
    * GET `/games/12377`
    * Authorization header using Bearer Token
  * Response
    * `{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text", "image_url": "URL"}`

#### Show Collections

* Show
  * Request
    * GET `/collections/USERNAME`
    * Authorization header using Bearer Token
  * Response
    * `{"id": 4, "bgg_username": "USERNAME", "status": "sync_completed", "updated_at": "2025-09-16T02:00:13.227Z", "games": []}`
* Get collection from user
  * Request
    * POST `/collections`
    * Authorization header using Bearer Token
    * Body: `{"username": "USERNAME"}`
  * Response
    * `{"status": "Import in progress."}`
