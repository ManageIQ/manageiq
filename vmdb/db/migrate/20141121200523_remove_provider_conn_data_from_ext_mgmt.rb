class RemoveProviderConnDataFromExtMgmt < ActiveRecord::Migration
  def up
    remove_column :ext_management_systems, :port
    remove_column :ext_management_systems, :ipaddress
    remove_column :ext_management_systems, :hostname
  end

  def down
    add_column    :ext_management_systems, :port, :string
    add_column    :ext_management_systems, :ipaddress, :string
    add_column    :ext_management_systems, :hostname, :string
  end
end
