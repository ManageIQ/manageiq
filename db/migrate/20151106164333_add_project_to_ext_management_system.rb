class AddProjectToExtManagementSystem < ActiveRecord::Migration
  def change
    add_column :ext_management_systems, :project, :string
  end
end
