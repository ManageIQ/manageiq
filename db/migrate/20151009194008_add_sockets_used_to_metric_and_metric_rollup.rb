class AddSocketsUsedToMetricAndMetricRollup < ActiveRecord::Migration
  def change
    add_column :metrics, :derived_sockets, :integer
    add_column :metric_rollups, :derived_sockets, :integer
  end
end
