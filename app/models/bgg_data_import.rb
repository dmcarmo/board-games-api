require "faraday"
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
      game = Game.find_by(bgg_id: boardgame_data[:bgg_id])
      if game.nil?
        Game.create(boardgame_data)
      else
        game.update(boardgame_data)
      end
    end
  end

  def boardgame_parser(boardgame)
    bgg_id = boardgame.attributes[:id]
    name = boardgame.locate("name").find { |line| line.attributes[:type] == "primary" }.attributes[:value]
    year = boardgame.yearpublished.attributes[:value]
    { name: name, bgg_id: bgg_id, yearpublished: year }
  end

  def last_id
    rss_url = "https://boardgamegeek.com/recentadditions/rss?subdomain=&infilters%5B0%5D=thing&infilters%5B1%5D=thinglinked&domain=boardgame"
    recent_additions = parse(rss_url)
    recent_additions.locate("rss/channel/item").map { |item| item.link.text.split("/")[4] }.max
    # recent_additions.locate("rss/channel/item").map { |item| /boardgame\/(\d+)\//.match(item.link.text)[1] }.max
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
