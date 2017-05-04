class AddSupportsHvmToFlavor < ActiveRecord::Migration[4.2]
  def change
    add_column :flavors, :supports_hvm, :boolean
    add_column :flavors, :supports_paravirtual, :boolean
  end
end
