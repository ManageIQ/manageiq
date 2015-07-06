class OntapRenameStatsToMetrics < ActiveRecord::Migration
  class MiqStorageStat < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  class MiqStorageMetric < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Change type of miq_storage_metrics to reflect renamed subclasses") do
      MiqStorageStat.all.each do |sm|
        if sm.type =~ /(.*)Stat$/
          sm.update_attribute(:type, "#{$1}Metric")
        end
      end
    end
    rename_table  :miq_storage_stats,               :miq_storage_metrics
    rename_column :miq_storage_metrics,             :stat_obj, :metric_obj

    remove_index  :ontap_aggregate_derived_stats,   :miq_storage_stat_id
    rename_table  :ontap_aggregate_derived_stats,   :ontap_aggregate_derived_metrics
    rename_column :ontap_aggregate_derived_metrics, :miq_storage_stat_id, :miq_storage_metric_id
    add_index     :ontap_aggregate_derived_metrics, :miq_storage_metric_id

    remove_index  :ontap_disk_derived_stats,        :miq_storage_stat_id
    rename_table  :ontap_disk_derived_stats,        :ontap_disk_derived_metrics
    rename_column :ontap_disk_derived_metrics,      :miq_storage_stat_id, :miq_storage_metric_id
    add_index     :ontap_disk_derived_metrics,      :miq_storage_metric_id

    remove_index  :ontap_lun_derived_stats,         :miq_storage_stat_id
    rename_table  :ontap_lun_derived_stats,         :ontap_lun_derived_metrics
    rename_column :ontap_lun_derived_metrics,       :miq_storage_stat_id, :miq_storage_metric_id
    add_index     :ontap_lun_derived_metrics,       :miq_storage_metric_id

    remove_index  :ontap_system_derived_stats,      :miq_storage_stat_id
    rename_table  :ontap_system_derived_stats,      :ontap_system_derived_metrics
    rename_column :ontap_system_derived_metrics,    :miq_storage_stat_id, :miq_storage_metric_id
    add_index     :ontap_system_derived_metrics,    :miq_storage_metric_id

    remove_index  :ontap_volume_derived_stats,      :miq_storage_stat_id
    rename_table  :ontap_volume_derived_stats,      :ontap_volume_derived_metrics
    rename_column :ontap_volume_derived_metrics,    :miq_storage_stat_id, :miq_storage_metric_id
    add_index     :ontap_volume_derived_metrics,    :miq_storage_metric_id

    remove_index  :miq_cim_derived_stats,           :miq_storage_stat_id
    rename_table  :miq_cim_derived_stats,           :miq_cim_derived_metrics
    rename_column :miq_cim_derived_metrics,         :miq_storage_stat_id, :miq_storage_metric_id
    add_index     :miq_cim_derived_metrics,         :miq_storage_metric_id

    remove_index  :miq_cim_instances,                :stat_id
    rename_column :miq_cim_instances,                :stat_id, :metric_id
    add_index     :miq_cim_instances,                :metric_id
    remove_index  :miq_cim_instances,                :stat_top_id
    rename_column :miq_cim_instances,                :stat_top_id, :metric_top_id
    add_index     :miq_cim_instances,                :metric_top_id

  end

  def down
    say_with_time("Change type of miq_storage_stats to reflect renamed subclasses") do
      MiqStorageMetric.all.each do |sm|
        if sm.type =~ /(.*)Metric$/
          sm.update_attribute(:type, "#{$1}Stat")
        end
      end
    end
    rename_table  :miq_storage_metrics,             :miq_storage_stats
    rename_column :miq_storage_stats,               :metric_obj, :stat_obj

    remove_index  :ontap_aggregate_derived_metrics, :miq_storage_metric_id
    rename_table  :ontap_aggregate_derived_metrics, :ontap_aggregate_derived_stats
    rename_column :ontap_aggregate_derived_stats,   :miq_storage_metric_id, :miq_storage_stat_id
    add_index     :ontap_aggregate_derived_stats,   :miq_storage_stat_id

    remove_index  :ontap_disk_derived_metrics,      :miq_storage_metric_id
    rename_table  :ontap_disk_derived_metrics,      :ontap_disk_derived_stats
    rename_column :ontap_disk_derived_stats,        :miq_storage_metric_id, :miq_storage_stat_id
    add_index     :ontap_disk_derived_stats,        :miq_storage_stat_id

    remove_index  :ontap_lun_derived_metrics,       :miq_storage_metric_id
    rename_table  :ontap_lun_derived_metrics,       :ontap_lun_derived_stats
    rename_column :ontap_lun_derived_stats,         :miq_storage_metric_id, :miq_storage_stat_id
    add_index     :ontap_lun_derived_stats,         :miq_storage_stat_id

    remove_index  :ontap_system_derived_metrics,    :miq_storage_metric_id
    rename_table  :ontap_system_derived_metrics,    :ontap_system_derived_stats
    rename_column :ontap_system_derived_stats,      :miq_storage_metric_id, :miq_storage_stat_id
    add_index     :ontap_system_derived_stats,      :miq_storage_stat_id

    remove_index  :ontap_volume_derived_metrics,    :miq_storage_metric_id
    rename_table  :ontap_volume_derived_metrics,    :ontap_volume_derived_stats
    rename_column :ontap_volume_derived_stats,      :miq_storage_metric_id, :miq_storage_stat_id
    add_index     :ontap_volume_derived_stats,      :miq_storage_stat_id

    remove_index  :miq_cim_derived_metrics,         :miq_storage_metric_id
    rename_table  :miq_cim_derived_metrics,         :miq_cim_derived_stats
    rename_column :miq_cim_derived_stats,           :miq_storage_metric_id, :miq_storage_stat_id
    add_index     :miq_cim_derived_stats,           :miq_storage_stat_id

    remove_index  :miq_cim_instances,               :metric_id
    rename_column :miq_cim_instances,               :metric_id, :stat_id
    add_index     :miq_cim_instances,               :stat_id
    remove_index  :miq_cim_instances,               :metric_top_id
    rename_column :miq_cim_instances,               :metric_top_id, :stat_top_id
    add_index     :miq_cim_instances,               :stat_top_id

  end
end
