class RemoveIsDatacenterFromEmsFolder < ActiveRecord::Migration[5.0]
  def change
    remove_column :ems_folders, :is_datacenter, :boolean
  end
end
