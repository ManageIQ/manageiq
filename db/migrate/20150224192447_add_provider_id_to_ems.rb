class AddProviderIdToEms < ActiveRecord::Migration[4.2]
  def change
    add_column :ext_management_systems, :provider_id, :bigint
  end
end
