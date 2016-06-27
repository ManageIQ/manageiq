class FixCounterpartIndexOnConfiguredSystems < ActiveRecord::Migration[5.0]
  def change
    remove_index :configured_systems, :column => [:counterpart_type, :counterpart_id ]
    add_index :configured_systems, [:counterpart_id, :counterpart_type]
  end
end
