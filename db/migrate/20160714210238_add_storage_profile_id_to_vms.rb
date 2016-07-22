class AddStorageProfileIdToVms < ActiveRecord::Migration[5.0]
  def change
    add_column :vms, :storage_profile_id, :bigint
  end
end
