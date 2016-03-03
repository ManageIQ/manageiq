class AddInventoryRootGroupIdToConfiguredSystems < ActiveRecord::Migration[5.0]
  def change
    add_column :configured_systems, :inventory_root_group_id, :bigint
  end
end
