class AddNameToCloudObjectStoreObject < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_object_store_objects, :name, :string
  end
end
