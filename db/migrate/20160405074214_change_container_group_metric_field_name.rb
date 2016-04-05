class ChangeContainerGroupMetricFieldName < ActiveRecord::Migration[5.0]
  def change
    rename_column :metric_rollups, :stat_containergroup_create_rate, :stat_container_group_create_rate
    rename_column :metric_rollups, :stat_containergroup_delete_rate, :stat_container_group_delete_rate
  end
end
