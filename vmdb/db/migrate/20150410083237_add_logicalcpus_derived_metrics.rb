class AddLogicalcpusDerivedMetrics < ActiveRecord::Migration
  def change
    # metrics_xx and metrics_rollups_xx automatically inherit this change
    add_column :metrics, :derived_logicalcpus_used, :float
    add_column :metric_rollups, :derived_logicalcpus_used, :float
    add_column :metrics, :derived_logicalcpus_available, :integer
    add_column :metric_rollups, :derived_logicalcpus_available, :integer
  end
end
