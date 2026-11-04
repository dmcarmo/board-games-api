class CreateGameVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :game_versions do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :bgg_id
      t.string :edition
      t.string :year_published
      t.string :languages, default: [], array: true
      t.string :publishers, default: [], array: true

      t.timestamps
    end

    add_index :game_versions, :bgg_id, unique: true
  end
end
