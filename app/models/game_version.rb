class GameVersion < ApplicationRecord
  belongs_to :game
  has_many :collection_games, dependent: :nullify
end
