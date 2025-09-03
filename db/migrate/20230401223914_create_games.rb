class CreateGames < ActiveRecord::Migration[7.0]
  def change
    create_table :games do |t|
      t.string :name
      t.integer :bgg_id
      t.string :yearpublished

      t.timestamps
    end
  end
end
