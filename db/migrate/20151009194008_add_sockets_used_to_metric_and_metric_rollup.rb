class AddSocketsUsedToMetricAndMetricRollup < ActiveRecord::Migration
  def change
    add_column :metrics,        :derived_host_sockets, :integer
    add_column :metric_rollups, :derived_host_sockets, :integer
  end
end
