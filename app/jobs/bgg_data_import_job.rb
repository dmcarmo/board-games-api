require "faraday"
require "open-uri"
require "ox"

OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

class BggDataImportJob < ApplicationJob
  queue_as :bgg_data_import

  MIN_DURATION = ENV.fetch("API_THROTTLE_SECONDS", 5).to_i.seconds
  MAX_BGG_ID_SLICE = 20

  retry_on Faraday::TimeoutError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on Faraday::ConnectionFailed, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on Faraday::ServerError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5

  def self.exponential_backoff(attempt)
    # Ensure minimum wait time respects API throttling (5 seconds minimum)
    base_wait = 2**attempt
    [base_wait, MIN_DURATION].max
  end
  private_class_method :exponential_backoff

  def perform(ids, batch_size, update_existing: false)
    base_games_buffer = []
    expansions_buffer = []
    image_jobs = []

    ids.each_slice(MAX_BGG_ID_SLICE) do |api_ids|
      start_time = Time.now
      url = "#{Game::API_URL}thing?type=boardgame,boardgameexpansion&id=#{api_ids.join(',')}"
      xml = parse(url)
      if xml
        parse_data(xml) do |batch_games, batch_expansions, batch_images|
          base_games_buffer.concat(batch_games)
          expansions_buffer.concat(batch_expansions)
          image_jobs.concat(batch_images)

          # Flush buffer if reached batch_size
          if (base_games_buffer.size + expansions_buffer.size) >= batch_size
            flush_buffer(base_games_buffer, expansions_buffer, image_jobs,
                         update_existing: update_existing)
          end
        end
      end

      # Throttle API requests
      elapsed = Time.now - start_time
      remaining = MIN_DURATION - elapsed
      sleep(remaining) if remaining.positive?
    end
    return unless base_games_buffer.any? || expansions_buffer.any?

    flush_buffer(base_games_buffer, expansions_buffer, image_jobs,
                 update_existing: update_existing)
  end

  private

  def parse_data(xml)
    batch_games = []
    batch_expansions = []
    batch_images = []
    boardgames = xml.locate("items/item")
    boardgames.each do |boardgame|
      game, image = boardgame_parser(boardgame)
      if game[:base_game_id].nil?
        batch_games << game
      else
        batch_expansions << game
      end
      batch_images << image
    end
    yield batch_games, batch_expansions, batch_images
  end

  def boardgame_parser(boardgame)
    name = boardgame.locate("name[@type=primary]/@value").first
    bgg_id = boardgame.attributes[:id]&.to_i
    base_game_id = find_base_game_id(boardgame)
    year = boardgame.locate("yearpublished/@value").first
    image_url = boardgame.locate("image/*").first
    min_players = boardgame.locate("minplayers/@value").first&.to_i
    max_players = boardgame.locate("maxplayers/@value").first&.to_i
    best_at = boardgame.locate("poll-summary[@name=suggested_numplayers]/result[@name=bestwith]/@value").first.match(/(\d+(?:\D\d+)?)/)&.[](1)
    recommended_at = boardgame.locate("poll-summary[@name=suggested_numplayers]/result[@name=recommmendedwith]/@value").first.match(/(\d+(?:\D\d+)?)/)&.[](1)
    min_playtime = boardgame.locate("minplaytime/@value").first&.to_i
    max_playtime = boardgame.locate("maxplaytime/@value").first&.to_i
    min_age = boardgame.locate("minage/@value").first&.to_i
    alternative_names = boardgame.locate("name[@type=alternate]/@value")
    language_dependence = language_dependence_parser(boardgame)
    now = Time.current

    [
      {
        name: name,
        bgg_id: bgg_id,
        base_game_id: base_game_id,
        year_published: year,
        min_players: min_players,
        max_players: max_players,
        best_at: best_at,
        recommended_at: recommended_at,
        min_playtime: min_playtime,
        max_playtime: max_playtime,
        min_age: min_age,
        alternative_names: alternative_names,
        language_dependence: language_dependence,
        created_at: now,
        updated_at: now
      },
      {
        bgg_id: bgg_id,
        image_url: image_url
      }
    ]
  rescue StandardError => e
    raise "Failed to parse boardgame ID #{bgg_id} (#{name}): #{e.message}"
  end

  def find_base_game_id(xml)
    return unless xml.attributes[:type] == "boardgameexpansion"

    xml.locate("link[@type=boardgameexpansion]/@id").first&.to_i
  end

  def find_altername_names(xml)
    return unless xml.attributes[:type] == "boardgameexpansion"

    xml.locate("link[@type=boardgameexpansion]/@id").first&.to_i
  end

  def language_dependence_parser(boardgame)
    language_poll = boardgame.locate("poll[@name=language_dependence]/*/*").map do |element|
      { votes: element.attributes[:numvotes].to_i, value: element.attributes[:value] }
    end
    value = language_poll.empty? ? nil : language_poll.max_by { |element| element[:votes] }[:value]
    Game.map_language_dependence(value)
  end

  def parse(url)
    response = Faraday.get(url)
    unless response.success?
      Rails.logger.warn("Request for #{url} failed with #{response.status} #{response.reason_phrase}")
      raise Faraday::ServerError, "Request failed with #{response.status}"
    end
    Ox.parse(response.body)
  rescue Faraday::TimeoutError => e
    Rails.logger.warn("Timeout while fetching #{url}: #{e.message}")
    raise StandardError, "Giving up on the server. Got error: #{e.message}"
  rescue Faraday::ConnectionFailed => e
    Rails.logger.warn("Connection failed for #{url}: #{e.message}")
    raise
  end

  def flush_buffer(base_games_buffer, expansions_buffer, image_jobs, update_existing: false)
    return if base_games_buffer.empty? && expansions_buffer.empty?

    if update_existing
      Game.upsert_all(base_games_buffer, unique_by: :bgg_id) if base_games_buffer.any?
      Game.upsert_all(expansions_buffer, unique_by: :bgg_id) if expansions_buffer.any?
    else
      Game.insert_all(base_games_buffer) if base_games_buffer.any?
      Game.insert_all(expansions_buffer) if expansions_buffer.any?
    end

    base_games_buffer.clear
    expansions_buffer.clear

    image_jobs.each { |image| ImageAttachJob.perform_later(image[:bgg_id], image[:image_url]) }
    image_jobs.clear
  end
end
