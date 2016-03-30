class AddVirtualInstanceRefToConfiguredSystems < ActiveRecord::Migration[5.0]
  def change
    add_column :configured_systems, :virtual_instance_ref, :string
  end
end
