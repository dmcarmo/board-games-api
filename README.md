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
    * GET `/api-keys/:id`
    * Authorization header using Bearer Token
  * Response
    * `{"id": 1, "bearer_type": "User", "revoked_at": null}`
* Deslete a token
  * Request
    * DELETE `/api-keys/:id`
    * Authorization header using Bearer Token
  * Response
    * `{"id": 1, "bearer_type": "User", "revoked_at": 2025-05-12T18:11:23.105Z}`
* List all Games
  * Request
    * GET `/games`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text"}, ...]`
* Search Games
  * Request
    * GET `/games?search=GAME-NAME`
    * Authorization header using Bearer Token
  * Response
    * `[{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text"}, ...]`
* Show Game
  * Request
    * GET `/games/:id`
    * Authorization header using Bearer Token
  * Response
    * `{"id": 12377, "name": "Can't Stop", "bgg_id": "41", "year_published": "1980", "created_at": "2025-02-23T00:48:12.693Z", "updated_at": "2025-02-23T01:57:12.422Z", "min_players": 2, "max_players": 4, "language_dependence": "No necessary in-game text", "image_url": "URL"}`
