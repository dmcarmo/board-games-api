require "faraday"
require "open-uri"
require "ox"

OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

class BggDataImportJob < ApplicationJob
  queue_as :bgg_data_import

  MIN_DURATION = ENV.fetch("API_THROTTLE_SECONDS", 5).to_i.seconds
  MAX_BGG_ID_SLICE = 20
  FLUSH_THRESHOLD = 200

  class BggApiClientError < StandardError; end # 4xx (excluding 429) — not retryable
  class BggApiServerError < StandardError; end # 5xx and 429 — retryable

  retry_on Faraday::TimeoutError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on Faraday::ConnectionFailed, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on BggApiServerError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5

  rescue_from BggApiClientError do |error|
    Rails.error.report(error)
    # not retryable — bad token, bad id, or malformed response; retrying won't fix it
  end

  def self.exponential_backoff(attempt)
    # Ensure minimum wait time respects API throttling (5 seconds minimum)
    base_wait = 2**attempt
    [base_wait, MIN_DURATION].max
  end
  private_class_method :exponential_backoff

  def perform(ids)
    base_games_buffer = []
    expansions_buffer = []
    image_jobs = []
    versions_buffer = []

    ids.each_slice(MAX_BGG_ID_SLICE) do |api_ids|
      start_time = Time.now
      url = "#{Game::API_URL}thing?type=boardgame,boardgameexpansion&stats=1&versions=1&id=#{api_ids.join(',')}"
      xml = parse(url)
      if xml
        parse_data(xml) do |batch_games, batch_expansions, batch_images, batch_versions|
          base_games_buffer.concat(batch_games)
          expansions_buffer.concat(batch_expansions)
          image_jobs.concat(batch_images)
          versions_buffer.concat(batch_versions)

          # Flush buffer if reached FLUSH_THRESHOLD
          if (base_games_buffer.size + expansions_buffer.size) >= FLUSH_THRESHOLD
            flush_buffer(base_games_buffer, expansions_buffer, image_jobs, versions_buffer)
          end
        end
      end

      # Throttle API requests
      elapsed = Time.now - start_time
      remaining = MIN_DURATION - elapsed
      sleep(remaining) if remaining.positive?
    end
    return unless base_games_buffer.any? || expansions_buffer.any?

    flush_buffer(base_games_buffer, expansions_buffer, image_jobs, versions_buffer)
  end

  private

  def parse_data(xml)
    batch_games = []
    batch_expansions = []
    batch_images = []
    batch_versions = []
    boardgames = xml.locate("items/item")

    boardgames.each do |boardgame|
      begin
        game, image, versions = boardgame_parser(boardgame)
      rescue StandardError => e
        Rails.error.report(e, context: { bgg_item_id: boardgame.attributes[:id] })
        next
      end

      if boardgame.attributes[:type] == "boardgameexpansion"
        batch_expansions << game
      else
        batch_games << game
      end
      batch_images << image
      batch_versions.concat(versions)
    end
    yield batch_games, batch_expansions, batch_images, batch_versions
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
    description = boardgame.locate("*/description").first&.text
    weight = boardgame.locate("*/averageweight/@value").first&.to_f
    now = Time.current

    versions = boardgame.locate("versions/item")
    versions_data = []

    versions.each do |version|
      versions_data << {
        bgg_id: version.locate("@id").first&.to_i,
        game_id: version.locate("link[@type=boardgameversion]/@id").first&.to_i,
        edition: version.locate("name[@type=primary]/@value").first,
        year_published: version.locate("yearpublished/@value").first,
        languages: version.locate("link[@type=language]/@value"),
        publishers: version.locate("link[@type=boardgamepublisher]/@value"),
      }
    end

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
        description: description,
        weight: weight,
        created_at: now,
        updated_at: now
      },
      {
        bgg_id: bgg_id,
        image_url: image_url
      },
      versions_data
    ]
  end

  def find_base_game_id(xml)
    return unless xml.attributes[:type] == "boardgameexpansion"

    xml.locate("link").find do |element|
      element[:type] == "boardgameexpansion" && element[:inbound] == "true"
    end&.[](:id)&.to_i
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
    response = Faraday.get(url, nil, { 'Authorization' => "Bearer #{ENV["BGG_TOKEN"]}" })

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

  def flush_buffer(base_games_buffer, expansions_buffer, image_jobs, versions_buffer)
    return if base_games_buffer.empty? && expansions_buffer.empty?

    Game.upsert_all(base_games_buffer, unique_by: :bgg_id) if base_games_buffer.any?
    if expansions_buffer.any?
      convert_bgg_ids_to_db_ids(expansions_buffer)
      Game.upsert_all(expansions_buffer, unique_by: :bgg_id)
    end

    if versions_buffer.any?
      convert_bgg_ids_to_db_ids(versions_buffer)
      GameVersion.upsert_all(versions_buffer, unique_by: :bgg_id)
    end

    base_games_buffer.clear
    expansions_buffer.clear
    versions_buffer.clear

    image_jobs.each { |image| ImageAttachJob.perform_later(image[:bgg_id], image[:image_url]) }
    image_jobs.clear
  end

  def convert_bgg_ids_to_db_ids(data_buffer)
    # Convert BGG game_id to actual database ID (modifies buffer in place)
    if data_buffer.first[:base_game_id]
      bgg_ids = data_buffer.map { |data| data[:base_game_id] }.compact.uniq
    else
      bgg_ids = data_buffer.map { |data| data[:game_id] }.compact.uniq
    end

    bgg_to_db_id_map = Game.where(bgg_id: bgg_ids).pluck(:bgg_id, :id).to_h

    data_buffer.each do |data|
      if data[:base_game_id]
        data[:base_game_id] = bgg_to_db_id_map[data[:base_game_id]]
      else
        data[:game_id] = bgg_to_db_id_map[data[:game_id]]
      end
    end
  end
end
