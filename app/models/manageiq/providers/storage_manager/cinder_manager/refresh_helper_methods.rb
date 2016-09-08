module ManageIQ::Providers::StorageManager::CinderManager::RefreshHelperMethods
  extend ActiveSupport::Concern

  def parse_backup(backup)
    uid = backup['id']
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
      :availability_zone     => @data_index.fetch_path(:availability_zones,
            "volume-" + backup['availability_zone'] || "null_az"),
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
      :availability_zone => @data_index.fetch_path(:availability_zones, "volume-" + volume.availability_zone || "null_az"),
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
    # Cinder v1
    return volume.display_name if volume.respond_to?(:display_name)
    # Cinder v2
    return volume.name
  end 

  def volume_description(volume)
    # Cinder v1
    return volume.display_description if volume.respond_to?(:display_description)
    # Cinder v2
    return volume.description
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

  def process_collection(collection, key, &block)
    @data[key] ||= []
    return if @options && @options[:inventory_ignore] && @options[:inventory_ignore].include?(key)
    # safe_call catches and ignores all Fog relation calls inside processing, causing allowed excon errors
    collection.each { |item| safe_call { process_collection_item(item, key, &block) } }
  end

  def process_collection_item(item, key)
    @data[key] ||= []

    uid, new_result = yield(item)

    @data[key] << new_result
    @data_index.store_path(key, uid, new_result)
    new_result
  end

  def safe_call
    # Safe call wrapper for any Fog call not going through handled_list
    yield
  rescue Excon::Errors::Forbidden => err
    # It can happen user doesn't have rights to read some tenant, in that case log warning but continue refresh
    _log.warn "Forbidden response code returned in provider: #{@os_handle.address}. Message=#{err.message}"
    _log.warn err.backtrace.join("\n")
    nil
  rescue Excon::Errors::NotFound => err
    # It can happen that some data do not exist anymore,, in that case log warning but continue refresh
    _log.warn "Not Found response code returned in provider: #{@os_handle.address}. Message=#{err.message}"
    _log.warn err.backtrace.join("\n")
    nil
  end

  alias safe_get safe_call

  def safe_list(&block)
    safe_call(&block) || []
  end
end
