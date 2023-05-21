require "faraday"
require "open-uri"
require "ox"

class BggDataImport
  def run
    # ids_range = (1..last_id)
    ids_range = (1..5)
    # ids_range.each_slice(1200) do |ids|
    ids_range.each_slice(2) do |ids|
      # each slice/batch should be scheduled into a job
      # each job should be able to handle timeout errors and implement exponential back-off
      # should also have a delay of 1 min (maybe less? some people are using 10 seconds) after the previous one was executed
      url = "#{Game::API_URL}thing?type=boardgame,boardgameexpansion&id=#{ids.join(',')}"
      xml = parse(url)
      parse_data(xml) unless xml.nil?
      sleep(30.seconds)
    end
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
        file = URI.parse(image_url).open
        extension = file.base_uri.path.split(".").last
        game.image.attach(io: file, filename: "cover.#{extension}", content_type: "image/#{extension}")
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
      { votes: element.attributes[:numvotes].to_i, value: element.attributes[:value].to_i }
    end
    # language_dependence = language_poll.max_by { |element| element[:votes] }[:value]
    # [language_poll, language_dependence] # will need to change the db to save the full poll
    language_poll.max_by { |element| element[:votes] }[:value]
  end

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
      Rails.logger.warn { "Request returned #{response.code}, #{response.reason_phrase}" }
      nil
    end
  end
end
