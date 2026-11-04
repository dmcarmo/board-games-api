class AddGameVersionToCollectionGames < ActiveRecord::Migration[7.2]
  def change
    add_reference :collection_games, :game_version, null: true, foreign_key: true
  end
end
