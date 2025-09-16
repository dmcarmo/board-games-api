class Collection < ApplicationRecord
  enum :status, {
    never_synced: 0,
    pending: 1,
    syncing: 2,
    sync_completed: 3,
    sync_failed: 4
  }

  has_many :collection_games, dependent: :destroy
  has_many :games, through: :collection_games
end
