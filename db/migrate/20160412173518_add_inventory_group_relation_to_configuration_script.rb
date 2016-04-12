class AddInventoryGroupRelationToConfigurationScript < ActiveRecord::Migration[5.0]
  def change
    add_reference :configuration_scripts, :inventory_root_group, :type => :bigint
  end
end
