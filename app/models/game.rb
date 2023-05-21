# frozen_string_literal: true

class Game < ApplicationRecord
  has_one_attached :image

  # WEB_URL = "https://boardgamegeek.com/boardgame/"
  # API_URL = "https://boardgamegeek.com/xmlapi2/"

  include PgSearch::Model
  pg_search_scope :search_by_name,
                  against: :name,
                  using: {
                    tsearch: { prefix: true }
                  }
end
