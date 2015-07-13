class AddSupports32BitAnd64BitToFlavors < ActiveRecord::Migration
  def change
    add_column :flavors, :supports_32_bit, :boolean
    add_column :flavors, :supports_64_bit, :boolean
  end
end
