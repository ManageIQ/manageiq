class ChangeDataTypeForColumnVendorInVmsTableToCitext < ActiveRecord::Migration[5.0]
  def up
    change_column :vms, :vendor, :citext
  end

  def down
    change_column :vms, :vendor, :string
  end
end
