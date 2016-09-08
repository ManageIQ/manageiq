#
#
#
module ManageIQ::Providers
  class StorageManager::CinderManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
    include ManageIQ::Providers::StorageManager::CinderManager::RefreshHelperMethods
    include Vmdb::Logging

    attr_accessor :data

    def self.ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, options = nil)

      @ems               = ems
      @connection        = ems.connect
      @data              = {}
      @data_index        = {}

        
      @cinder_service    = ems.parent_manager.cinder_service
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $fog_log.info("#{log_header}...")
      get_volumes
      get_snapshots
      # TODO: volume backups
      #get_backups

      $fog_log.info("#{log_header}...Complete")

      link_storage_associations

      @data
    end

    def volumes
      @volumes ||= @cinder_service.handled_list(:volumes)
    end

    def get_volumes
      process_collection(volumes, :cloud_volumes) { |volume| parse_volume(volume) }
    end

    def get_snapshots
      process_collection(@cinder_service.handled_list(:list_snapshots_detailed,
                                                      :__request_body_index => "snapshots"),
                         :cloud_volume_snapshots) { |snap| parse_snapshot(snap) }
    end

    def get_backups
      process_collection(@cinder_service.handled_list(:list_backups_detailed,
                                                      :__request_body_index => "backups"),
                         :cloud_volume_backups) { |backup| parse_backup(backup) }

    end

  end
end
