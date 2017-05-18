class AddProjectToExtManagementSystem < ActiveRecord::Migration[4.2]
  def change
    add_column :ext_management_systems, :project, :string
  end
end
