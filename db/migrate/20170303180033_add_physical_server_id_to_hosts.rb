class AddPhysicalServerIdToHosts < ActiveRecord::Migration[5.0]
  def change
    add_column :hosts, :physical_server_id, :bigint
  end
end
