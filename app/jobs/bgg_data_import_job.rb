require "faraday"
require "open-uri"
require "ox"

OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

class BggDataImportJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(ids)
    url = "#{Game::API_URL}thing?type=boardgame,boardgameexpansion&id=#{ids.join(',')}"
    xml = parse(url)
    parse_data(xml) unless xml.nil?
  end

  private

  def parse_data(xml)
    boardgames = xml.locate("items/item")
    boardgames.each do |boardgame|
      boardgame_data = boardgame_parser(boardgame)
      image_url = boardgame_data.delete(:image_url)
      game = Game.find_by(bgg_id: boardgame_data[:bgg_id])
      if game.nil?
        game = Game.create(boardgame_data)
        attach_image(game, image_url) if Rails.env.production? && !image_url.nil?
      else
        game.update(boardgame_data)
      end
    end
  end

  def boardgame_parser(boardgame)
    bgg_id = boardgame.attributes[:id]
    name = boardgame.locate("name[@type=primary]/@value").first
    year = boardgame.locate("yearpublished/@value").first
    image_url = boardgame.locate("image/*").first
    min_players = boardgame.locate("minplayers/@value").first.to_i
    max_players = boardgame.locate("maxplayers/@value").first.to_i
    # language_poll, language_dependence = language_dependence_parser(boardgame)
    language_dependence = language_dependence_parser(boardgame)

    {
      name: name,
      bgg_id: bgg_id,
      year_published: year,
      min_players: min_players,
      max_players: max_players,
      language_dependence: language_dependence,
      image_url: image_url
    }
  end

  def language_dependence_parser(boardgame)
    language_poll = boardgame.locate("poll[@name=language_dependence]/*/*").map do |element|
      { votes: element.attributes[:numvotes].to_i, value: element.attributes[:value] }
    end
    # language_dependence = language_poll.max_by { |element| element[:votes] }[:value]
    # [language_poll, language_dependence] # will need to change the db to save the full poll
    language_poll.empty? ? nil : language_poll.max_by { |element| element[:votes] }[:value]
  end

  def attach_image(game, image_url)
    retries = 0
    max_retries = 8
    begin
      file = URI.parse(image_url).open
      filename = file.base_uri.path.split("/").last
      extension = filename.split(".").last
      type = extension == "jpg" ? "image/jpeg" : "image/#{extension}"
      resized = ImageProcessing::MiniMagick
                .source(file)
                .resize_to_limit(1024, 1024)
                .call
      game.image.attach(io: resized, filename: filename, content_type: type)
    rescue Errno::ECONNRESET => e
      puts image_url
      raise "Giving up on the server after #{retries} retries. Got error: #{e.message}" unless retries <= max_retries

      sleep_time = (2**retries) + 10
      puts "Sleeping for #{sleep_time} seconds"
      retries += 1
      sleep sleep_time
      retry
    end
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
