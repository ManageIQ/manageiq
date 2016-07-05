class CreateStorageProfiles < ActiveRecord::Migration[5.0]
  def change
    create_table :storage_profiles do |t|
      t.string :name
      t.string :uuid
      t.string :profile_type

      t.timestamps
    end
  end
end
