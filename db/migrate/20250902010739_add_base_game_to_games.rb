class AddBaseGameToGames < ActiveRecord::Migration[7.2]
  def change
    add_reference :games, :base_game, foreign_key: { to_table: :games }
  end
end
