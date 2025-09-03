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
    (2**attempt) + rand(1..5)
  end
  private_class_method :exponential_backoff

  def perform(ids, batch_size, update_existing: false)
    buffer = []
    image_jobs = []

    ids.each_slice(MAX_BGG_ID_SLICE) do |api_ids|
      start_time = Time.now
      url = "#{Game::API_URL}thing?type=boardgame,boardgameexpansion&id=#{api_ids.join(',')}"
      xml = parse(url)
      if xml
        parse_data(xml) do |batch_games, batch_images|
          buffer.concat(batch_games)
          image_jobs.concat(batch_images)

          # Flush buffer if reached batch_size
          flush_buffer(buffer, image_jobs, update_existing: update_existing) if buffer.size >= batch_size
        end
      end

      # Throttle API requests
      elapsed = Time.now - start_time
      remaining = MIN_DURATION - elapsed
      sleep(remaining) if remaining.positive?
    end
    flush_buffer(buffer, image_jobs, update_existing: update_existing) if buffer.any?
  end

  private

  def parse_data(xml)
    batch_games = []
    batch_images = []
    boardgames = xml.locate("items/item")
    boardgames.each do |boardgame|
      game, image = boardgame_parser(boardgame)
      batch_games << game
      batch_images << image
    end
    yield batch_games, batch_images
  end

  def boardgame_parser(boardgame)
    bgg_id = boardgame.attributes[:id]&.to_i
    name = boardgame.locate("name[@type=primary]/@value").first
    year = boardgame.locate("yearpublished/@value").first
    image_url = boardgame.locate("image/*").first
    min_players = boardgame.locate("minplayers/@value").first&.to_i
    max_players = boardgame.locate("maxplayers/@value").first&.to_i
    # language_poll, language_dependence = language_dependence_parser(boardgame)
    language_dependence = language_dependence_parser(boardgame)
    now = Time.current

    [
      {
        name: name,
        bgg_id: bgg_id,
        year_published: year,
        min_players: min_players,
        max_players: max_players,
        language_dependence: language_dependence,
        created_at: now,
        updated_at: now
      },
      {
        bgg_id: bgg_id,
        image_url: image_url
      }
    ]
  end

  def language_dependence_parser(boardgame)
    language_poll = boardgame.locate("poll[@name=language_dependence]/*/*").map do |element|
      { votes: element.attributes[:numvotes].to_i, value: element.attributes[:value] }
    end
    # language_dependence = language_poll.max_by { |element| element[:votes] }[:value]
    # [language_poll, language_dependence] # will need to change the db to save the full poll
    language_poll.empty? ? nil : language_poll.max_by { |element| element[:votes] }[:value]
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

  def flush_buffer(buffer, image_jobs, update_existing: false)
    return if buffer.empty?

    if update_existing
      Game.upsert_all(buffer, unique_by: :bgg_id)
    else
      Game.insert_all(buffer)
    end
    buffer.clear

    image_jobs.each { |image| ImageAttachJob.perform_later(image[:bgg_id], image[:image_url]) }
    image_jobs.clear
  end
end
