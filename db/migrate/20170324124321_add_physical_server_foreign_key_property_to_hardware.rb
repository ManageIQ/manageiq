class AddPhysicalServerForeignKeyPropertyToHardware < ActiveRecord::Migration[5.0]
  def change
    add_column :hardwares, :physical_server_id, :string, index: true
  end
end
