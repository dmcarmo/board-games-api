# frozen_string_literal: true

class Game < ApplicationRecord
  include PgSearch::Model

  WEB_URL = "https://boardgamegeek.com/boardgame/"
  API_URL = "https://boardgamegeek.com/xmlapi2/"

  LANGUAGE_DEPENDENCE_MAP = {
    "No necessary" => :no_necessary,
    "Some necessary" => :some_necessary,
    "Moderate" => :moderate,
    "Extensive" => :extensive,
    "Unplayable" => :unplayable
  }.freeze

  def self.map_language_dependence(value)
    return :not_available if value.nil?

    key = LANGUAGE_DEPENDENCE_MAP.keys.find { |prefix| value.start_with?(prefix) }
    LANGUAGE_DEPENDENCE_MAP[key]
  end

  enum :language_dependence, {
    not_available: 0,
    no_necessary: 1,
    some_necessary: 2,
    moderate: 3,
    extensive: 4,
    unplayable: 5
  }

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
