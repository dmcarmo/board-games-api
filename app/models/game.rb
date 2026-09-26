# frozen_string_literal: true
require "mini_magick"

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

  enum :language_dependence, {
    not_available: 0,
    no_necessary: 1,
    some_necessary: 2,
    moderate: 3,
    extensive: 4,
    unplayable: 5
  }

  has_many :collection_games, dependent: :destroy
  belongs_to :base_game, class_name: "Game", optional: true
  has_many :expansions, class_name: "Game", foreign_key: "base_game_id", dependent: :destroy
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

  def self.map_language_dependence(value)
    return :not_available if value.nil?

    key = LANGUAGE_DEPENDENCE_MAP.keys.find { |prefix| value.start_with?(prefix) }
    LANGUAGE_DEPENDENCE_MAP[key]
  end

  def base_game?
    base_game_id.nil?
  end

  def expansion?
    base_game_id.present?
  end

  def image_url
    Rails.application.routes.url_helpers.api_permanent_image_url(image.key) if image.attached?
  end

  def image_aspect_ratio
    return nil unless image.attached?

    width = image.blob.metadata[:width]
    height = image.blob.metadata[:height]

    if width.present? && height.present? && !height.zero?
      return width.to_f / height
    end

    calculate_and_cache_old_aspect_ratio
  end

  private

  def calculate_and_cache_old_aspect_ratio
    image.blob.open do |file|
      img = MiniMagick::Image.new(file.path)
      return nil if img.height.zero?

      calculated_ratio = img.width.to_f / img.height

      image.blob.update!(
        metadata: image.blob.metadata.merge(
          width: img.width,
          height: img.height,
          analyzed: true
        )
      )

      calculated_ratio
    end
  rescue => e
    Rails.logger.error("ActiveStorage Fallback Failed: #{e.message}")
    nil
  end
end
