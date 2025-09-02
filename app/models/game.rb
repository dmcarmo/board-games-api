# frozen_string_literal: true

class Game < ApplicationRecord
  include PgSearch::Model

  WEB_URL = "https://boardgamegeek.com/boardgame/"
  API_URL = "https://boardgamegeek.com/xmlapi2/"

  belongs_to :base_game, class_name: "Game", optional: true
  has_many :expansions, class_name: "Game", foreign_key: "base_game_id"
  has_one_attached :image

  scope :base_games, -> { where(base_game_id: nil) }
  scope :expansions, -> { where.not(base_game_id: nil) }
  scope :search_by_bgg_id, ->(bgg_id) { where(bgg_id: bgg_id) if bgg_id.present? }
  scope :search_by_name_exact, ->(name) { where("LOWER(name) = ?", name.strip.downcase) if name.present? }

  pg_search_scope :search_by_name_partial,
                  against: :name,
                  using: {
                    trigram: {}
                  }

  def base_game?
    base_game_id.nil?
  end

  def expansion?
    base_game_id.present?
  end
end
