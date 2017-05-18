class AddTypeToCloudObjectStoreContainer < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_object_store_containers, :type, :string
    add_index :cloud_object_store_containers, :type
  end
end
