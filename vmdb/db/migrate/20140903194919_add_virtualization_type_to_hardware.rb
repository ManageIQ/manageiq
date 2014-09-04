class AddVirtualizationTypeToHardware < ActiveRecord::Migration
  def change
    add_column :hardwares, :virtualization_type, :string
  end
end
