require "faraday"
require "ox"

class ImportJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 1000

  def perform(update_existing: false)
    full_range_of_ids = Rails.env.production? ? (1..last_id).to_a : (1..30).to_a
    ids_to_process = if update_existing
                       full_range_of_ids
                     else
                       existing_ids = Game.where(bgg_id: full_range_of_ids).pluck(:bgg_id)
                       full_range_of_ids - existing_ids
                     end

    ids_to_process.each_slice(BATCH_SIZE) do |ids|
      BggDataImportJob.perform_later(ids, BATCH_SIZE, update_existing: update_existing)
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
