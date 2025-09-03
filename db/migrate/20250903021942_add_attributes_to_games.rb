class AddAttributesToGames < ActiveRecord::Migration[7.2]
  def change
    add_column :games, :min_playtime, :integer
    add_column :games, :max_playtime, :integer
    add_column :games, :min_age, :string
    add_column :games, :best_at, :string
    add_column :games, :recommended_at, :string
    add_column :games, :alternative_names, :string, array: true, default: []
  end
end
