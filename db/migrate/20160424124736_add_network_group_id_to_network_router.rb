class AddNetworkGroupIdToNetworkRouter < ActiveRecord::Migration
  def change
    add_column :network_routers, :network_group_id, :bigint

    add_index :network_routers, :network_group_id
  end
end
