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
      @options           = options || {}
      @data              = {}
      @data_index        = {}

      @cinder_service    = ems.parent_manager.cinder_service
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $fog_log.info("#{log_header}...")
      get_volumes
      get_snapshots
      get_backups

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
      process_collection(@cinder_service.list_backups_detailed.body["backups"],
                         :cloud_volume_backups) { |backup| parse_backup(backup) }
    end

    def parse_backup(backup)
      uid = backup['id']
      az = backup['availability_zone'].nil? ? "null_az" : "volume-" + backup['availability_zone']
      new_result = {
        :ems_ref               => uid,
        :type                  => "ManageIQ::Providers::Openstack::CloudManager::CloudVolumeBackup",
        # Supporting both Cinder v1 and Cinder v2
        :name                  => backup['display_name'] || backup['name'],
        :status                => backup['status'],
        :creation_time         => backup['created_at'],
        # Supporting both Cinder v1 and Cinder v2
        :description           => backup['display_description'] || backup['description'],
        :size                  => backup['size'].to_i.gigabytes,
        :object_count          => backup['object_count'].to_i,
        :is_incremental        => backup['is_incremental'],
        :has_dependent_backups => backup['has_dependent_backups'],
        :availability_zone     => @data_index.fetch_path(:availability_zones, az),
        :volume                => @data_index.fetch_path(:cloud_volumes, backup['volume_id'])
      }
      return uid, new_result
    end

    def parse_snapshot(snap)
      uid = snap['id']
      new_result = {
        :ems_ref       => uid,
        :type          => "ManageIQ::Providers::Openstack::CloudManager::CloudVolumeSnapshot",
        # Supporting both Cinder v1 and Cinder v2
        :name          => snap['display_name'] || snap['name'],
        :status        => snap['status'],
        :creation_time => snap['created_at'],
        # Supporting both Cinder v1 and Cinder v2
        :description   => snap['display_description'] || snap['description'],
        :size          => snap['size'].to_i.gigabytes,
        :tenant        => @data_index.fetch_path(:cloud_tenants, snap['os-extended-snapshot-attributes:project_id']),
        :volume        => @data_index.fetch_path(:cloud_volumes, snap['volume_id'])
      }
      return uid, new_result
    end

    def parse_volume(volume)
      log_header = "MIQ(#{self.class.name}.#{__method__})"

      uid = volume.id
      new_result = {
        :ems_ref           => uid,
        # TODO: has its own CloudVolume?
        :type              => "ManageIQ::Providers::Openstack::CloudManager::CloudVolume",
        :name              => volume_name(volume),
        :status            => volume.status,
        :bootable          => volume.attributes['bootable'],
        :creation_time     => volume.created_at,
        :description       => volume_description(volume),
        :volume_type       => volume.volume_type,
        :snapshot_uid      => volume.snapshot_id,
        :size              => volume.size.to_i.gigabytes,
        :tenant            => @data_index.fetch_path(:cloud_tenants, volume.tenant_id),
        :availability_zone => @data_index.fetch_path(:availability_zones,
                              "volume-" + volume.availability_zone || "null_az"),
      }

      volume.attachments.each do |a|
        if a['device'].blank?
          _log.warn "#{log_header}: Volume: #{uid}, is missing a mountpoint, skipping the volume processing"
          _log.warn "#{log_header}:   EMS: #{@ems.name}, Instance: #{a['server_id']}"
          next
        end

        dev = File.basename(a['device'])
        disks = @data_index.fetch_path(:vms, a['server_id'], :hardware, :disks)

        unless disks
          _log.warn "#{log_header}: Volume: #{uid}, attached to instance not visible in the scope of this EMS"
          _log.warn "#{log_header}:   EMS: #{@ems.name}, Instance: #{a['server_id']}"
          next
        end

        if (disk = disks.detect { |d| d[:location] == dev })
          disk[:size] = new_result[:size]
        else
          disk = add_instance_disk(disks, new_result[:size], dev, "OpenStack Volume")
        end

        if disk
          disk[:backing]      = new_result
          disk[:backing_type] = 'CloudVolume'
        end
      end

      return uid, new_result
    end

    def volume_name(volume)
      # Cinder v1 : Cinder v2
      volume.respond_to?(:display_name) ? volume.display_name : volume.name
    end

    def volume_description(volume)
      # Cinder v1 : Cinder v2
      volume.respond_to?(:display_description) ? volume.display_description : volume.description
    end

    def add_instance_disk(disks, size, location, name, controller_type)
      if size >= 0
        disk = {
          :device_name     => name,
          :device_type     => "disk",
          :controller_type => controller_type,
          :location        => location,
          :size            => size
        }
        disks << disk
        return disk
      end
      nil
    end

    def link_storage_associations
      @data[:cloud_volumes].each do |cv|
        #
        # Associations between volumes and the snapshots on which
        # they are based, if any.
        #
        base_snapshot_uid = cv.delete(:snapshot_uid)
        base_snapshot = @data_index.fetch_path(:cloud_volume_snapshots, base_snapshot_uid)
        cv[:base_snapshot] = base_snapshot unless base_snapshot.nil?
      end if @data[:cloud_volumes]
    end
  end
end
