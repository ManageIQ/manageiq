class AddVendorPropertyToPhysicalServer < ActiveRecord::Migration[5.0]
  def change
    add_column :physical_servers, :vendor, :string
  end
end
