class AddParentEmsIdToExtManagementSystem < ActiveRecord::Migration[5.0]
  def change
    add_column :ext_management_systems, :parent_ems_id, :bigint

    add_index :ext_management_systems, :parent_ems_id
  end
end
