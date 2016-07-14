class CreateJoinTableStorageProfileStorage < ActiveRecord::Migration[5.0]
  def change
    create_table :storage_profile_storages do |t|
      t.bigint  :storage_profile_id
      t.bigint  :storage_id
      t.index   :storage_id
      t.index   :storage_profile_id
    end
  end
end
