class CollectionGame < ApplicationRecord
  belongs_to :collection
  belongs_to :game
  belongs_to :game_version, optional: true
end
