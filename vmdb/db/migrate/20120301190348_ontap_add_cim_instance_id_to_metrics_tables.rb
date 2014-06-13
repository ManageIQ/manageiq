class OntapAddCimInstanceIdToMetricsTables < ActiveRecord::Migration
  class MiqStorageMetric < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    has_one :miq_cim_instance, :foreign_key => "metric_id", :class_name => "::OntapAddCimInstanceIdToMetricsTables::MiqCimInstance"
  end

  class MiqCimInstance              < ActiveRecord::Base; end

  class OntapAggregateDerivedMetric < ActiveRecord::Base; end
  class OntapAggregateMetricsRollup < ActiveRecord::Base; end
  class OntapDiskDerivedMetric      < ActiveRecord::Base; end
  class OntapDiskMetricsRollup      < ActiveRecord::Base; end
  class OntapLunDerivedMetric       < ActiveRecord::Base; end
  class OntapLunMetricsRollup       < ActiveRecord::Base; end
  class OntapSystemDerivedMetric    < ActiveRecord::Base; end
  class OntapSystemMetricsRollup    < ActiveRecord::Base; end
  class OntapVolumeDerivedMetric    < ActiveRecord::Base; end
  class OntapVolumeMetricsRollup    < ActiveRecord::Base; end

  def up
    add_column  :ontap_aggregate_derived_metrics, :miq_cim_instance_id, :bigint
    add_index   :ontap_aggregate_derived_metrics, :miq_cim_instance_id
    add_column  :ontap_aggregate_metrics_rollups, :miq_cim_instance_id, :bigint
    add_index   :ontap_aggregate_metrics_rollups, :miq_cim_instance_id

    add_column  :ontap_disk_derived_metrics,      :miq_cim_instance_id, :bigint
    add_index   :ontap_disk_derived_metrics,      :miq_cim_instance_id
    add_column  :ontap_disk_metrics_rollups,      :miq_cim_instance_id, :bigint
    add_index   :ontap_disk_metrics_rollups,      :miq_cim_instance_id

    add_column  :ontap_lun_derived_metrics,       :miq_cim_instance_id, :bigint
    add_index   :ontap_lun_derived_metrics,       :miq_cim_instance_id
    add_column  :ontap_lun_metrics_rollups,       :miq_cim_instance_id, :bigint
    add_index   :ontap_lun_metrics_rollups,       :miq_cim_instance_id

    add_column  :ontap_system_derived_metrics,    :miq_cim_instance_id, :bigint
    add_index   :ontap_system_derived_metrics,    :miq_cim_instance_id
    add_column  :ontap_system_metrics_rollups,    :miq_cim_instance_id, :bigint
    add_index   :ontap_system_metrics_rollups,    :miq_cim_instance_id

    add_column  :ontap_volume_derived_metrics,    :miq_cim_instance_id, :bigint
    add_index   :ontap_volume_derived_metrics,    :miq_cim_instance_id
    add_column  :ontap_volume_metrics_rollups,    :miq_cim_instance_id, :bigint
    add_index   :ontap_volume_metrics_rollups,    :miq_cim_instance_id

    say_with_time("Assign miq_cim_instance_id to derived_metrics and metrics_rollups tables") do
      MiqStorageMetric.find_each do |sm|
        ci = MiqCimInstance.where(:metric_id => sm.id).select(:id).first
        if ci.nil?
          say "Could not find corresponding MiqCimInstance for MiqStorageMetric.id = #{sm.id}"
        else
          case sm.type
          when "OntapAggregateMetric"
            OntapAggregateDerivedMetric.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
            OntapAggregateMetricsRollup.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
          when "OntapDiskMetric"
            OntapDiskDerivedMetric.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
            OntapDiskMetricsRollup.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
          when "OntapLunMetric"
            OntapLunDerivedMetric.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
            OntapLunMetricsRollup.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
          when "OntapSystemMetric"
            OntapSystemDerivedMetric.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
            OntapSystemMetricsRollup.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
          when "OntapVolumeMetric"
            OntapVolumeDerivedMetric.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
            OntapVolumeMetricsRollup.where(:miq_storage_metric_id => sm.id).update_all(:miq_cim_instance_id => ci.id)
          end
        end
      end
    end
  end

  def down
    remove_index  :ontap_aggregate_derived_metrics, :miq_cim_instance_id
    remove_column :ontap_aggregate_derived_metrics, :miq_cim_instance_id
    remove_index  :ontap_aggregate_metrics_rollups, :miq_cim_instance_id
    remove_column :ontap_aggregate_metrics_rollups, :miq_cim_instance_id

    remove_index  :ontap_disk_derived_metrics,      :miq_cim_instance_id
    remove_column :ontap_disk_derived_metrics,      :miq_cim_instance_id
    remove_index  :ontap_disk_metrics_rollups,      :miq_cim_instance_id
    remove_column :ontap_disk_metrics_rollups,      :miq_cim_instance_id

    remove_index  :ontap_lun_derived_metrics,       :miq_cim_instance_id
    remove_column :ontap_lun_derived_metrics,       :miq_cim_instance_id
    remove_index  :ontap_lun_metrics_rollups,       :miq_cim_instance_id
    remove_column :ontap_lun_metrics_rollups,       :miq_cim_instance_id

    remove_index  :ontap_system_derived_metrics,    :miq_cim_instance_id
    remove_column :ontap_system_derived_metrics,    :miq_cim_instance_id
    remove_index  :ontap_system_metrics_rollups,    :miq_cim_instance_id
    remove_column :ontap_system_metrics_rollups,    :miq_cim_instance_id

    remove_index  :ontap_volume_derived_metrics,    :miq_cim_instance_id
    remove_column :ontap_volume_derived_metrics,    :miq_cim_instance_id
    remove_index  :ontap_volume_metrics_rollups,    :miq_cim_instance_id
    remove_column :ontap_volume_metrics_rollups,    :miq_cim_instance_id
  end
end
