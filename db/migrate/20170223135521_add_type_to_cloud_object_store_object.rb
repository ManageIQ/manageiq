class AddTypeToCloudObjectStoreObject < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_object_store_objects, :type, :string
    add_index :cloud_object_store_objects, :type
  end
end
