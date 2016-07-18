class CreateStorageProfiles < ActiveRecord::Migration[5.0]
  def change
    create_table :storage_profiles do |t|
      t.bigint :ems_id
      t.string :name
      t.string :ems_ref
      t.string :profile_type

      t.timestamps
    end
  end
end
