class AddVirtualizationTypeToHardware < ActiveRecord::Migration[4.2]
  def change
    add_column :hardwares, :virtualization_type, :string
  end
end
