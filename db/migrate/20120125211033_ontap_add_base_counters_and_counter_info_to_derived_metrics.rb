class OntapAddBaseCountersAndCounterInfoToDerivedMetrics < ActiveRecord::Migration
  def up
    add_column    :ontap_aggregate_derived_metrics, :base_counters, :text
    add_column    :ontap_aggregate_derived_metrics, :counter_info,  :text

    add_column    :ontap_disk_derived_metrics,      :base_counters, :text
    add_column    :ontap_disk_derived_metrics,      :counter_info,  :text

    add_column    :ontap_lun_derived_metrics,       :base_counters, :text
    add_column    :ontap_lun_derived_metrics,       :counter_info,  :text

    add_column    :ontap_system_derived_metrics,    :base_counters, :text
    add_column    :ontap_system_derived_metrics,    :counter_info,  :text

    add_column    :ontap_volume_derived_metrics,    :base_counters, :text
    add_column    :ontap_volume_derived_metrics,    :counter_info,  :text
  end

  def down
    remove_column :ontap_aggregate_derived_metrics, :base_counters
    remove_column :ontap_aggregate_derived_metrics, :counter_info

    remove_column :ontap_disk_derived_metrics,      :base_counters
    remove_column :ontap_disk_derived_metrics,      :counter_info

    remove_column :ontap_lun_derived_metrics,       :base_counters
    remove_column :ontap_lun_derived_metrics,       :counter_info

    remove_column :ontap_system_derived_metrics,    :base_counters
    remove_column :ontap_system_derived_metrics,    :counter_info

    remove_column :ontap_volume_derived_metrics,    :base_counters
    remove_column :ontap_volume_derived_metrics,    :counter_info
  end
end
