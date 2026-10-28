require "faraday"
require "ox"

class BggCreateCollectionJob < ApplicationJob
  queue_as :bgg_data_import

  MIN_DURATION = ENV.fetch("API_THROTTLE_SECONDS", 5).to_i.seconds

  class BggApiClientError < StandardError; end # 4xx (excluding 429) — not retryable
  class BggApiServerError < StandardError; end # 5xx and 429 — retryable

  retry_on Faraday::TimeoutError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on Faraday::ConnectionFailed, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5
  retry_on BggApiServerError, wait: ->(attempt) { exponential_backoff(attempt) }, attempts: 5

  def self.exponential_backoff(attempt)
    # Ensure minimum wait time respects API throttling (5 seconds minimum)
    base_wait = 2**attempt
    [base_wait, MIN_DURATION].max
  end
  private_class_method :exponential_backoff

  def perform(bgg_username)
    url = "#{Game::API_URL}user?name=#{bgg_username}"
    xml = parse(url)
    parsed_username = xml.locate("user/@name").first
    Collection.create(bgg_username: parsed_username)
  rescue StandardError => e
    raise "Failed to create collection for #{bgg_username}: #{e.message}"
  end

  private

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
end
