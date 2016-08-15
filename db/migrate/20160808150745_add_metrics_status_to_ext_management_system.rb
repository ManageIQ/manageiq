class AddMetricsStatusToExtManagementSystem < ActiveRecord::Migration[5.0]
  def change
    add_column :ext_management_systems, :last_metrics_error, :text
    add_column :ext_management_systems, :last_metrics_update_date, :timestamp
    add_column :ext_management_systems, :last_metrics_success_date, :timestamp
  end
end
