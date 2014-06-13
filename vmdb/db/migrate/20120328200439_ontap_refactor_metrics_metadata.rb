class OntapRefactorMetricsMetadata < ActiveRecord::Migration
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

  class StorageMetricsMetadata      < ActiveRecord::Base; end

  class OntapAggregateDerivedMetricMetadata < StorageMetricsMetadata; end
  class OntapAggregateMetricsRollupMetadata < StorageMetricsMetadata; end
  class OntapDiskDerivedMetricMetadata      < StorageMetricsMetadata; end
  class OntapDiskMetricsRollupMetadata      < StorageMetricsMetadata; end
  class OntapLunDerivedMetricMetadata       < StorageMetricsMetadata; end
  class OntapLunMetricsRollupMetadata       < StorageMetricsMetadata; end
  class OntapSystemDerivedMetricMetadata    < StorageMetricsMetadata; end
  class OntapSystemMetricsRollupMetadata    < StorageMetricsMetadata; end
  class OntapVolumeDerivedMetricMetadata    < StorageMetricsMetadata; end
  class OntapVolumeMetricsRollupMetadata    < StorageMetricsMetadata; end

  CLASS_MAP = {
    OntapAggregateDerivedMetric   => OntapAggregateDerivedMetricMetadata,
    OntapAggregateMetricsRollup   => OntapAggregateMetricsRollupMetadata,
    OntapDiskDerivedMetric        => OntapDiskDerivedMetricMetadata,
    OntapDiskMetricsRollup        => OntapDiskMetricsRollupMetadata,
    OntapLunDerivedMetric         => OntapLunDerivedMetricMetadata,
    OntapLunMetricsRollup         => OntapLunMetricsRollupMetadata,
    OntapSystemDerivedMetric      => OntapSystemDerivedMetricMetadata,
    OntapSystemMetricsRollup      => OntapSystemMetricsRollupMetadata,
    OntapVolumeDerivedMetric      => OntapVolumeDerivedMetricMetadata,
    OntapVolumeMetricsRollup      => OntapVolumeMetricsRollupMetadata
  }

  def up
    create_table :storage_metrics_metadata do |t|
      t.string     :type
      t.text       :counter_info
      t.timestamps
    end

    add_column  :ontap_aggregate_derived_metrics, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_aggregate_derived_metrics, :storage_metrics_metadata_id,
                :name => :index_ontap_aggregate_derived_metrics_on_smm_id
    add_column  :ontap_aggregate_metrics_rollups, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_aggregate_metrics_rollups, :storage_metrics_metadata_id,
                :name => :index_ontap_aggregate_metrics_rollups_on_smm_id

    add_column  :ontap_disk_derived_metrics, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_disk_derived_metrics, :storage_metrics_metadata_id,
                :name => :index_ontap_disk_derived_metrics_on_smm_id
    add_column  :ontap_disk_metrics_rollups, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_disk_metrics_rollups, :storage_metrics_metadata_id,
                :name => :index_ontap_disk_metrics_rollups_on_smm_id

    add_column  :ontap_lun_derived_metrics, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_lun_derived_metrics, :storage_metrics_metadata_id,
                :name => :index_ontap_lun_derived_metrics_on_smm_id
    add_column  :ontap_lun_metrics_rollups, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_lun_metrics_rollups, :storage_metrics_metadata_id,
                :name => :index_ontap_lun_metrics_rollups_on_smm_id

    add_column  :ontap_system_derived_metrics, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_system_derived_metrics, :storage_metrics_metadata_id,
                :name => :index_ontap_system_derived_metrics_on_smm_id
    add_column  :ontap_system_metrics_rollups, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_system_metrics_rollups, :storage_metrics_metadata_id,
                :name => :index_ontap_system_metrics_rollups_on_smm_id

    add_column  :ontap_volume_derived_metrics, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_volume_derived_metrics, :storage_metrics_metadata_id,
                :name => :index_ontap_volume_derived_metrics_on_smm_id
    add_column  :ontap_volume_metrics_rollups, :storage_metrics_metadata_id, :bigint
    add_index   :ontap_volume_metrics_rollups, :storage_metrics_metadata_id,
                :name => :index_ontap_volume_metrics_rollups_on_smm_id

    say_with_time("Factor out counter_info from derived_metrics and metrics_rollups tables") do
      CLASS_MAP.each do |metricsClass, metadataClass|
        next if (metricsObj = metricsClass.select(:counter_info).first).nil?

        # Not serialized, read the raw yaml string.
        counterInfo = metricsObj.counter_info
        # Not serialized, write the raw yaml string.
        metadataObj = metadataClass.create!(:counter_info => counterInfo)
        metricsClass.update_all(:storage_metrics_metadata_id => metadataObj.id)
      end
    end

    remove_column :ontap_aggregate_derived_metrics, :counter_info
    remove_column :ontap_aggregate_metrics_rollups, :counter_info

    remove_column :ontap_disk_derived_metrics,      :counter_info
    remove_column :ontap_disk_metrics_rollups,      :counter_info

    remove_column :ontap_lun_derived_metrics,       :counter_info
    remove_column :ontap_lun_metrics_rollups,       :counter_info

    remove_column :ontap_system_derived_metrics,    :counter_info
    remove_column :ontap_system_metrics_rollups,    :counter_info

    remove_column :ontap_volume_derived_metrics,    :counter_info
    remove_column :ontap_volume_metrics_rollups,    :counter_info
  end

  def down
    add_column :ontap_aggregate_derived_metrics, :counter_info, :text
    add_column :ontap_aggregate_metrics_rollups, :counter_info, :text

    add_column :ontap_disk_derived_metrics,      :counter_info, :text
    add_column :ontap_disk_metrics_rollups,      :counter_info, :text

    add_column :ontap_lun_derived_metrics,       :counter_info, :text
    add_column :ontap_lun_metrics_rollups,       :counter_info, :text

    add_column :ontap_system_derived_metrics,    :counter_info, :text
    add_column :ontap_system_metrics_rollups,    :counter_info, :text

    add_column :ontap_volume_derived_metrics,    :counter_info, :text
    add_column :ontap_volume_metrics_rollups,    :counter_info, :text

    say_with_time("Restore counter_info to derived_metrics and metrics_rollups tables") do
      CLASS_MAP.each do |metricsClass, metadataClass|
        next if (metadataObj = metadataClass.select(:counter_info).first).nil?

        # Not serialized, read the raw yaml string.
        counterInfo = metadataObj.counter_info
        # Saves yaml string directly into column.
        metricsClass.update_all(:counter_info => counterInfo)
      end
    end

    remove_index  :ontap_aggregate_derived_metrics,
                  :name => :index_ontap_aggregate_derived_metrics_on_smm_id
    remove_column :ontap_aggregate_derived_metrics, :storage_metrics_metadata_id
    remove_index  :ontap_aggregate_metrics_rollups,
                  :name => :index_ontap_aggregate_metrics_rollups_on_smm_id
    remove_column :ontap_aggregate_metrics_rollups, :storage_metrics_metadata_id

    remove_index  :ontap_disk_derived_metrics,
                  :name => :index_ontap_disk_derived_metrics_on_smm_id
    remove_column :ontap_disk_derived_metrics,      :storage_metrics_metadata_id
    remove_index  :ontap_disk_metrics_rollups,
                  :name => :index_ontap_disk_metrics_rollups_on_smm_id
    remove_column :ontap_disk_metrics_rollups,      :storage_metrics_metadata_id

    remove_index  :ontap_lun_derived_metrics,
                  :name => :index_ontap_lun_derived_metrics_on_smm_id
    remove_column :ontap_lun_derived_metrics,       :storage_metrics_metadata_id
    remove_index  :ontap_lun_metrics_rollups,
                  :name => :index_ontap_lun_metrics_rollups_on_smm_id
    remove_column :ontap_lun_metrics_rollups,       :storage_metrics_metadata_id

    remove_index  :ontap_system_derived_metrics,
                  :name => :index_ontap_system_derived_metrics_on_smm_id
    remove_column :ontap_system_derived_metrics,    :storage_metrics_metadata_id
    remove_index  :ontap_system_metrics_rollups,
                  :name => :index_ontap_system_metrics_rollups_on_smm_id
    remove_column :ontap_system_metrics_rollups,    :storage_metrics_metadata_id

    remove_index  :ontap_volume_derived_metrics,
                  :name => :index_ontap_volume_derived_metrics_on_smm_id
    remove_column :ontap_volume_derived_metrics,    :storage_metrics_metadata_id
    remove_index  :ontap_volume_metrics_rollups,
                  :name => :index_ontap_volume_metrics_rollups_on_smm_id
    remove_column :ontap_volume_metrics_rollups,    :storage_metrics_metadata_id

    drop_table :storage_metrics_metadata
  end
end
