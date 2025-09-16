class BggCollectionImportJob < ApplicationJob
  class RetryRequest < StandardError; end

  queue_as :bgg_data_import

  MIN_DURATION = ENV.fetch("API_THROTTLE_SECONDS", 5).to_i.seconds

  retry_on Faraday::TimeoutError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on Faraday::ConnectionFailed, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on Faraday::ServerError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5

  def self.exponential_backoff(attempt)
    # Ensure minimum wait time respects API throttling (5 seconds minimum)
    base_wait = 2**attempt
    [base_wait, MIN_DURATION].max
  end
  private_class_method :exponential_backoff

  def perform(bgg_username)
    url = "#{Game::API_URL}collection?username=#{bgg_username}"
    xml = parse(url)
    collection = Collection.find_or_create_by(bgg_username: bgg_username)
    collection.status = :syncing
    collection.save
    boardgames = xml.locate("items/item")
    games = boardgames.map { |boardgame| boardgame_parser(boardgame, collection) }.compact
    CollectionGame.insert_all(games) if games.any?
    collection.status = :sync_completed
    collection.save
  rescue StandardError => e
    raise "Failed to create collection for #{bgg_username}: #{e.message}"
  end

  private

  def boardgame_parser(boardgame, collection)
    bgg_id = boardgame.attributes[:objectid]&.to_i
    game_id = Game.find_by(bgg_id: bgg_id)&.id
    own = boardgame.locate("status").first.attributes[:own] == "1"
    previously_owned = boardgame.locate("status").first.attributes[:prevowned] == "1"
    for_trade = boardgame.locate("status").first.attributes[:fortrade] == "1"
    want = boardgame.locate("status").first.attributes[:want] == "1"
    want_to_play = boardgame.locate("status").first.attributes[:wanttoplay] == "1"
    want_to_buy = boardgame.locate("status").first.attributes[:wanttobuy] == "1"
    wishlist = boardgame.locate("status").first.attributes[:wishlist].to_i
    preordered = boardgame.locate("status").first.attributes[:preordered] == "1"
    last_modified = ActiveSupport::TimeZone['UTC'].parse(boardgame.locate("status").first.attributes[:lastmodified] || "")
    number_of_plays = boardgame.locate("numplays").first.text.to_i
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
    raise "Failed to parse boardgame ID #{bgg_id} (#{name}): #{e.message}"
  end

  def parse(url, max_retries: 5, wait_seconds: 5)
    retries = 0

    begin
      response = Faraday.get(url)
      if response.status == 200
        Ox.parse(response.body)
      elsif response.status == 202
        if retries < max_retries
          retries += 1
          Rails.logger.info("Data not ready (202) for #{url}. Retrying #{retries}/#{max_retries} in #{wait_seconds}s...")
          sleep(wait_seconds)
          raise RetryRequest
        else
          Rails.logger.warn("Max retries reached for #{url} (still 202)")
          raise StandardError, "Data not ready after #{max_retries} attempts"
        end
      else
        Rails.logger.warn("Request for #{url} failed with #{response.status} #{response.reason_phrase}")
        raise StandardError, "Request failed with #{response.status}"
      end
    rescue RetryRequest
      retry
    rescue Faraday::TimeoutError => e
      Rails.logger.warn("Timeout while fetching #{url}: #{e.message}")
      raise StandardError, "Giving up on the server. Got error: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      Rails.logger.warn("Connection failed for #{url}: #{e.message}")
      raise
    end
  end
end
