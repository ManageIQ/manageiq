class OntapRemovePositionFromMetricsTables < ActiveRecord::Migration
  def up
    remove_column :ontap_aggregate_derived_metrics, :position
    remove_column :ontap_aggregate_metrics_rollups, :position

    remove_column :ontap_disk_derived_metrics,      :position
    remove_column :ontap_disk_metrics_rollups,      :position

    remove_column :ontap_lun_derived_metrics,       :position
    remove_column :ontap_lun_metrics_rollups,       :position

    remove_column :ontap_system_derived_metrics,    :position
    remove_column :ontap_system_metrics_rollups,    :position

    remove_column :ontap_volume_derived_metrics,    :position
    remove_column :ontap_volume_metrics_rollups,    :position

    remove_column :miq_cim_derived_metrics,         :position
  end

  def down
    add_column :ontap_aggregate_derived_metrics,  :position, :integer
    add_column :ontap_aggregate_metrics_rollups,  :position, :integer

    add_column :ontap_disk_derived_metrics,       :position, :integer
    add_column :ontap_disk_metrics_rollups,       :position, :integer

    add_column :ontap_lun_derived_metrics,        :position, :integer
    add_column :ontap_lun_metrics_rollups,        :position, :integer

    add_column :ontap_system_derived_metrics,     :position, :integer
    add_column :ontap_system_metrics_rollups,     :position, :integer

    add_column :ontap_volume_derived_metrics,     :position, :integer
    add_column :ontap_volume_metrics_rollups,     :position, :integer

    add_column :miq_cim_derived_metrics,          :position, :integer
  end
end
