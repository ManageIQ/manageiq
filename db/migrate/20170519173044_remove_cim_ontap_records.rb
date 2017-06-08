class RemoveCimOntapRecords < ActiveRecord::Migration[5.0]
  class ServerRole < ActiveRecord::Base; end

  class AssignedServerRole < ActiveRecord::Base; end

  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  class MiqWorker < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiqProductFeature < ActiveRecord::Base; end

  class MiqRolesFeature < ActiveRecord::Base; end # Join table for MiqProductFeature<->MiqUserRole

  ROLES = %w(
    storage_inventory
    storage_metrics_collector
    storage_metrics_coordinator
    storage_metrics_processor
    vmdb_storage_bridge
  ).freeze

  WORKERS = %w(
    MiqNetappRefreshWorker
    MiqSmisRefreshWorker
    MiqStorageMetricsCollectorWorker
    MiqVmdbStorageBridgeWorker
  ).freeze

  SETTINGS = %w(
    /storage/inventory%
    /storage/metrics_collection%
    /storage/metrics_history%
    /storage/metrics_history%
    /workers/worker_base/smis_refresh_worker%
    /workers/worker_base/queue_worker_base/netapp_refresh_worker%
    /workers/worker_base/queue_worker_base/storage_metrics_collector_worker%
    /workers/worker_base/queue_worker_base/vmdb_storage_bridge_worker%
  ).freeze

  PRODUCT_FEATURES = %w(
    cim_base_storage_extent
    cim_base_storage_extent_control
    cim_base_storage_extent_show
    cim_base_storage_extent_show_list
    cim_base_storage_extent_statistics
    cim_base_storage_extent_tag
    cim_base_storage_extent_view
    ontap_file_share
    ontap_file_share_control
    ontap_file_share_create_datastore
    ontap_file_share_show
    ontap_file_share_show_list
    ontap_file_share_statistics
    ontap_file_share_tag
    ontap_file_share_view
    ontap_logical_disk
    ontap_logical_disk_control
    ontap_logical_disk_perf
    ontap_logical_disk_show
    ontap_logical_disk_show_list
    ontap_logical_disk_statistics
    ontap_logical_disk_tag
    ontap_logical_disk_view
    ontap_storage_system
    ontap_storage_system_control
    ontap_storage_system_create_logical_disk
    ontap_storage_system_show
    ontap_storage_system_show_list
    ontap_storage_system_statistics
    ontap_storage_system_tag
    ontap_storage_system_view
    ontap_storage_volume
    ontap_storage_volume_control
    ontap_storage_volume_show
    ontap_storage_volume_show_list
    ontap_storage_volume_statistics
    ontap_storage_volume_tag
    ontap_storage_volume_view
    snia_local_file_system
    snia_local_file_system_control
    snia_local_file_system_show
    snia_local_file_system_show_list
    snia_local_file_system_statistics
    snia_local_file_system_tag
    snia_local_file_system_view
    storage_manager
    storage_manager_admin
    storage_manager_control
    storage_manager_delete
    storage_manager_edit
    storage_manager_new
    storage_manager_refresh_inventory
    storage_manager_refresh_status
    storage_manager_show
    storage_manager_show_list
    storage_manager_view
  ).freeze

  def up
    say_with_time("Removing roles") do
      ServerRole.where(:name => ROLES).each do |role|
        AssignedServerRole.delete_all(:server_role_id => role.id)
        role.delete
      end
    end

    say_with_time("Removing roles from currently configured servers") do
      SettingsChange.where(:key => "/server/role").each do |change|
        role_list = change.value.split(",")
        new_role_list = (role_list - ROLES).join(",")
        change.update_attributes!(:value => new_role_list)
      end
    end

    say_with_time("Removing workers") do
      MiqWorker.where(:type => WORKERS).delete_all
    end

    say_with_time("Removing settings") do
      SETTINGS.each do |key|
        SettingsChange.where("key LIKE ?", key).delete_all
      end
    end

    say_with_time("Removing product features") do
      query = MiqProductFeature.where(:identifier => PRODUCT_FEATURES)
      ids = query.pluck(:id)
      query.delete_all
      MiqRolesFeature.where(:miq_product_feature_id => ids).delete_all
    end
  end
end
