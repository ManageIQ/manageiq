class ShowbackChangeMeasuretype < ActiveRecord::Migration[5.0]
  def self.up
    rename_table :showback_measure_types, :showback_usage_types
  end

  def self.down
    rename_table :showback_usage_types, :showback_measure_types
  end
end
