class AddSupportsHvmToFlavor < ActiveRecord::Migration
  def change
    add_column :flavors, :supports_hvm, :boolean
    add_column :flavors, :supports_paravirtual, :boolean
  end
end
