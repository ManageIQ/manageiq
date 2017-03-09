class AddProviderRegionToCloudObjectStoreContainer < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_object_store_containers, :provider_region, :string
  end
end
