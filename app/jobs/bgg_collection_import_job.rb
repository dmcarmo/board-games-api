class BggCollectionImportJob < ApplicationJob
  class RetryRequest < StandardError; end

  queue_as :bgg_data_import

  MIN_DURATION = ENV.fetch("API_THROTTLE_SECONDS", 5).to_i.seconds

  class BggApiClientError < StandardError; end # 4xx (excluding 429) — not retryable
  class BggApiServerError < StandardError; end # 5xx and 429 — retryable
  class BggApiPendingError < StandardError; end # 202 — collection still being prepared, retryable

  retry_on Faraday::TimeoutError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on Faraday::ConnectionFailed, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on BggApiServerError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on BggApiPendingError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5

  def self.exponential_backoff(attempt)
    # Ensure minimum wait time respects API throttling (5 seconds minimum)
    base_wait = 2**attempt
    [base_wait, MIN_DURATION].max
  end
  private_class_method :exponential_backoff

  def perform(bgg_username)
    boardgames_url = "#{Game::API_URL}collection?username=#{bgg_username}"
    expansions_url = "#{Game::API_URL}collection?username=#{bgg_username}&subtype=boardgameexpansion"

    collection = Collection.find_by(bgg_username: bgg_username)
    collection.update(status: :syncing)

    boardgames_xml = parse(boardgames_url)
    boardgames = boardgames_xml.locate("items/item")

    expansions_xml = parse(expansions_url)
    expansions = expansions_xml.locate("items/item")

    games = boardgames.concat(expansions).map { |boardgame| boardgame_parser(boardgame, collection) }.compact

    Collection.transaction do
      collection.collection_games.delete_all
      CollectionGame.insert_all(games) if games.any?
      collection.update!(status: :sync_completed)
    end
  rescue StandardError => e
    collection&.update(status: :sync_failed)
    raise "Failed to create collection for #{bgg_username}: #{e.message}"
  end

  private

  def boardgame_parser(boardgame, collection)
    bgg_id = boardgame.attributes[:objectid]&.to_i
    game_id = Game.find_by(bgg_id: bgg_id)&.id
    return unless game_id

    status = boardgame.locate("status").first&.attributes || {}
    own = status[:own] == "1"
    previously_owned = status[:prevowned] == "1"
    for_trade = status[:fortrade] == "1"
    want = status[:want] == "1"
    want_to_play = status[:wanttoplay] == "1"
    want_to_buy = status[:wanttobuy] == "1"
    wishlist = status[:wishlist].to_i
    preordered = status[:preordered] == "1"
    last_modified = ActiveSupport::TimeZone['UTC'].parse(status[:lastmodified] || "")
    number_of_plays = boardgame.locate("numplays").first.text.to_i || 0
    now = Time.current

    if game_id
      {
        collection_id: collection.id,
        game_id: game_id,
        own: own,
        previously_owned: previously_owned,
        for_trade: for_trade,
        want: want,
        want_to_play: want_to_play,
        want_to_buy: want_to_buy,
        wishlist: wishlist,
        preordered: preordered,
        last_modified: last_modified,
        number_of_plays: number_of_plays,
        created_at: now,
        updated_at: now
      }
    end
  rescue StandardError => e
    raise "Failed to parse boardgame ID #{bgg_id}: #{e.message}"
  end

  def parse(url)
    response = Faraday.get(url, nil, { 'Authorization' => "Bearer #{ENV["BGG_TOKEN"]}" })

    if response.status == 202
      message = "Data not ready (202) for #{url}"
      Rails.logger.info(message)
      raise BggApiPendingError, message
    end

    unless response.success?
      message = "Request for #{url} failed with #{response.status} #{response.reason_phrase}"

      if response.status.between?(400, 499) && response.status != 429
        Rails.logger.error(message)
        raise BggApiClientError, message
      else
        Rails.logger.warn(message)
        raise BggApiServerError, message
      end
    end

    Ox.parse(response.body)
  rescue Faraday::TimeoutError => e
    Rails.logger.warn("Timeout while fetching #{url}: #{e.message}")
    raise
  rescue Faraday::ConnectionFailed => e
    Rails.logger.warn("Connection failed for #{url}: #{e.message}")
    raise
  rescue Ox::Error => e
    Rails.logger.error("Failed to parse XML from #{url}: #{e.message}")
    raise BggApiClientError, "Malformed XML response: #{e.message}"
  end
end
