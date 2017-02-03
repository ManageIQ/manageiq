class DropPhServerIdColumnFromPhysicalServer < ActiveRecord::Migration[5.0]
  def change

    remove_column :firmwares, :ph_server_id

  end
end
