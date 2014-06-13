class AddFingerprintToAuthentications < ActiveRecord::Migration
  def change
    add_column :authentications, :fingerprint, :string
  end
end
