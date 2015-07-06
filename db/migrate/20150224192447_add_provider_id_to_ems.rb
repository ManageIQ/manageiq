class AddProviderIdToEms < ActiveRecord::Migration
  def change
    add_column :ext_management_systems, :provider_id, :bigint
  end
end
