class AddOldEmsIdToContainersAndDefinitions < ActiveRecord::Migration[5.0]
  def change
    add_column :containers, :old_ems_id, :bigint
    add_column :container_definitions, :old_ems_id, :bigint
  end
end
