class AddNameToCloudObjectStoreContainer < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_object_store_containers, :name, :string
  end
end
