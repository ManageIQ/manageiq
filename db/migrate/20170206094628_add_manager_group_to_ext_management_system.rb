class AddManagerGroupToExtManagementSystem < ActiveRecord::Migration[5.0]
  def change
    add_column :ext_management_systems, :manager_group, :string
  end
end
