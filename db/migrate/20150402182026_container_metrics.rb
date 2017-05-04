class ContainerMetrics < ActiveRecord::Migration[4.2]
  def change
    add_column :container_nodes, :last_perf_capture_on, :datetime
    add_column :containers, :last_perf_capture_on, :datetime
    add_column :container_groups, :last_perf_capture_on, :datetime
  end
end
