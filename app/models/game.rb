# frozen_string_literal: true

class Game < ApplicationRecord
  has_one_attached :image

  WEB_URL = "https://boardgamegeek.com/boardgame/"
  API_URL = "https://boardgamegeek.com/xmlapi2/"
end
