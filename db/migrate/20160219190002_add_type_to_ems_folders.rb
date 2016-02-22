class AddTypeToEmsFolders < ActiveRecord::Migration[5.0]
  def change
    add_column :ems_folders, :type, :string
  end
end
