require "faraday"
require "ox"

class ImportJob < ApplicationJob
  queue_as :default

  def perform
    ids_range = Rails.env.production? ? (1..last_id) : (1..5)
    ids_range.each_slice(20) do |ids|
      BggDataImportJob.set(wait: 3.seconds).perform_later(ids)
    end
  end

  private

  def last_id
    rss_url = "https://boardgamegeek.com/recentadditions/rss?subdomain=&infilters%5B0%5D=thing&infilters%5B1%5D=thinglinked&domain=boardgame"
    recent_additions = parse(rss_url)
    recent_additions.locate("rss/channel/item/link/^Text").map { |url| url.split("/")[4].to_i }.max
  end

  def parse(url)
    response = Faraday.get(url)
    if response.success?
      Ox.parse(response.body)
    else
      Rails.logger.warn { "Request for #{url} failed" }
      Rails.logger.warn { "Request returned #{response.status}, #{response.reason_phrase}" }
      nil
    end
  rescue Faraday::TimeoutError => e
    puts url
    raise "Giving up on the server. Got error: #{e.message}"
  end
end
