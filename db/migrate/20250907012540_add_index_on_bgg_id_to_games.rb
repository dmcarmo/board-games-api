class AddIndexOnBggIdToGames < ActiveRecord::Migration[7.2]
  def change
    add_index :games, :bgg_id, unique: true
  end
end
