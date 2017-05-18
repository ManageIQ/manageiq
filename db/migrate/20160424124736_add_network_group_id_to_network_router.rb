class AddNetworkGroupIdToNetworkRouter < ActiveRecord::Migration[4.2]
  def change
    add_column :network_routers, :network_group_id, :bigint

    add_index :network_routers, :network_group_id
  end
end
