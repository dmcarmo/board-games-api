class CreateCollectionGames < ActiveRecord::Migration[7.2]
  def change
    create_table :collection_games do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.boolean :own
      t.boolean :previously_owned
      t.boolean :for_trade
      t.boolean :want
      t.boolean :want_to_play
      t.boolean :want_to_buy
      t.integer :wishlist
      t.boolean :preordered
      t.timestamp :last_modified
      t.integer :number_of_plays

      t.timestamps
    end
  end
end
