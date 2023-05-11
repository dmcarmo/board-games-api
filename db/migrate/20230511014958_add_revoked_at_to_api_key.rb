class AddRevokedAtToApiKey < ActiveRecord::Migration[7.0]
  def change
    add_column :api_keys, :revoked_at, :datetime, default: nil
  end
end
