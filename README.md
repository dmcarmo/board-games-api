# README

## Development

* rails db:create db:migrate
* rails s
* bundle exec good_job start

## Production

* secrets are set in `credentials.yml.enc` so we need to pass `RAILS_MASTER_KEY` as a env variable with the value from the local `master.key`

---

## Notes

* base games vs expansions?

```html
<link type="boardgameexpansion" id="130486" value="Small City" inbound="true"/>
<link type="boardgamedesigner" id="6048" value="Alban Viard"/>
<link type="boardgamepublisher" id="30685" value="AVStudioGames"/>

if <item type="boardgameexpansion" -> get <link type="boardgameexpansion" id="130486" (id = bgg_id)
```
