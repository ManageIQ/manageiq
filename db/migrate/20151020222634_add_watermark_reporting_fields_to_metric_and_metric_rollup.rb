class AddWatermarkReportingFieldsToMetricAndMetricRollup < ActiveRecord::Migration
  def change
    add_column :metrics,        :derived_host_sockets,     :integer
    add_column :metrics,        :derived_host_count_total, :integer
    add_column :metrics,        :derived_vm_count_total,   :integer
    add_column :metric_rollups, :derived_host_sockets,     :integer
    add_column :metric_rollups, :derived_host_count_total, :integer
    add_column :metric_rollups, :derived_vm_count_total,   :integer
  end
end
