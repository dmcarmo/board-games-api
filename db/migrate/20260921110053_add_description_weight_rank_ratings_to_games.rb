class AddDescriptionWeightRankRatingsToGames < ActiveRecord::Migration[7.2]
  def change
    add_column :games, :description, :text
    add_column :games, :weight, :float
    add_column :games, :rank, :integer
    add_column :games, :average_rating, :float
    add_column :games, :bayesian_rating, :float
  end
end
