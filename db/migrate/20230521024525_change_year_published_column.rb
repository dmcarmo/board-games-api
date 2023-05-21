class ChangeYearPublishedColumn < ActiveRecord::Migration[7.0]
  def change
    rename_column :games, :yearpublished, :year_published
  end
end
