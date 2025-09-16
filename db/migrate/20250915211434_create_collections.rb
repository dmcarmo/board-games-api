class CreateCollections < ActiveRecord::Migration[7.2]
  def change
    create_table :collections do |t|
      t.string :bgg_username, null: false
      t.index [:bgg_username], name: "index_collections_on_bgg_username"
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
