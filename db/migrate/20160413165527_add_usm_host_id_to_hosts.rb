class AddUsmHostIdToHosts < ActiveRecord::Migration[5.0]
  def change
    add_column :hosts, :usm_host_id, :bigint
  end
end
