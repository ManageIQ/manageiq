module ManageIQ::Providers::StorageManager::CinderManager::RefreshParser::CrossLinkers
  class Openstack
    include Vmdb::Logging

    def initialize(parent_ems, data)
      @parent_ems = parent_ems
      @data       = data

      @parent_ems.cloud_tenants.reset
      @parent_ems.availability_zones.reset
      @parent_ems.vms.reset
    end

    def cross_link
      @data[:cloud_volumes].each do |volume_hash|
        api_obj = volume_hash[:api_obj]

        link_volume_to_tenant(volume_hash, api_obj)
        link_volume_to_availability_zone(volume_hash, api_obj)
        link_volume_to_disk(volume_hash, api_obj)
      end

      @data[:cloud_volume_snapshots].each do |snapshot_hash|
        api_obj = snapshot_hash[:api_obj]

        link_snapshot_to_tenant(snapshot_hash, api_obj)
      end

      @data[:cloud_volume_backups].each do |backup_hash|
        api_obj = backup_hash[:api_obj]

        link_backup_to_availability_zone(backup_hash, api_obj)
      end
    end

    def link_volume_to_tenant(volume_hash, api_obj)
      tenant = @parent_ems.cloud_tenants.detect { |t| t.ems_ref == api_obj.tenant_id }
      unless tenant
        _log.info("EMS: #{@parent_ems.name}, tenant not found: #{api_obj.tenant_id}")
        return
      end
      _log.debug("Found tenant: #{api_obj.tenant_id}, id = #{tenant.id}")

      volume_hash[:cloud_tenant_id] = tenant.id
    end

    def link_volume_to_availability_zone(volume_hash, api_obj)
      az_ref = api_obj.availability_zone ? api_obj.availability_zone : "null_az"
      availability_zone = @parent_ems.availability_zones.detect { |az| az.ems_ref == az_ref }
      unless availability_zone
        _log.info("EMS: #{@parent_ems.name}, availability zone not found: #{az_ref}")
        return
      end
      _log.debug("Found availability zone: #{az_ref}, id = #{availability_zone.id}")

      volume_hash[:availability_zone_id] = availability_zone.id
    end

    def link_snapshot_to_tenant(snapshot_hash, api_obj)
      tenant_ref = api_obj['os-extended-snapshot-attributes:project_id']
      tenant = @parent_ems.cloud_tenants.detect { |t| t.ems_ref == tenant_ref }
      unless tenant
        _log.info("EMS: #{@parent_ems.name}, tenant not found: #{tenant_ref}")
        return
      end
      _log.debug("Found tenant: #{tenant_ref}, id = #{tenant.id}")

      snapshot_hash[:cloud_tenant_id] = tenant.id
    end

    def link_backup_to_availability_zone(backup_hash, api_obj)
      az_ref = api_obj['availability_zone'] ? api_obj['availability_zone'] : "null_az"
      availability_zone = @parent_ems.availability_zones.detect { |az| az.ems_ref == az_ref }
      unless availability_zone
        _log.info("EMS: #{@parent_ems.name}, availability zone not found: #{az_ref}")
        return
      end
      _log.debug("Found availability zone: #{az_ref}, id = #{availability_zone.id}")

      backup_hash[:availability_zone_id] = availability_zone.id
    end

    def link_volume_to_disk(volume_hash, api_obj)
      uid = api_obj.id

      api_obj.attachments.each do |a|
        if a['device'].blank?
          _log.warn("#{log_header}: Volume: #{uid}, is missing a mountpoint, skipping the volume processing")
          _log.warn("#{log_header}:   EMS: #{@ems.name}, Instance: #{a['server_id']}")
          next
        end

        dev = File.basename(a['device'])

        vm = @parent_ems.vms.detect { |v| v.ems_ref == a['server_id'] }
        unless vm
          _log.warn("VM referenced by backing volume not found.")
          next
        end

        hardware = vm.hardware
        disks = hardware.disks

        unless disks
          _log.warn("#{log_header}: Volume: #{uid}, attached to instance not visible in the scope of this EMS")
          _log.warn("#{log_header}:   EMS: #{@ems.name}, Instance: #{a['server_id']}")
          next
        end

        disk_hash = {
          :size           => api_obj.size.gigabytes,
          :backing_volume => volume_hash
        }

        if (disk = disks.detect { |d| d.location == dev })
          # Disk exists: save id.
          disk_hash[:id] = disk.id
        else
          # New disk.
          disk_hash[:hardware_id]     = hardware.id
          disk_hash[:device_name]     = dev
          disk_hash[:device_type]     = "disk"
          disk_hash[:controller_type] = "OpenStack Volume"
          disk_hash[:location]        = dev
        end

        backing_links << disk_hash
      end
    end

    def backing_links
      @data[:backing_links] ||= []
    end
  end
end
