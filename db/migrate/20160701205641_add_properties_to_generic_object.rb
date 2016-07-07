class AddPropertiesToGenericObject < ActiveRecord::Migration[5.0]
  def change
    add_column :generic_objects, :properties, :jsonb, :default => {}
  end
end
