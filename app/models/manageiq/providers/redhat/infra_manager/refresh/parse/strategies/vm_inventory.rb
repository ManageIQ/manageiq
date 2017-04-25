module ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies
  class VmInventory
    attr_reader :host_inv, :_log

    def initialize(args)
      @host_inv = args[:inv]
      @_log = args[:logger]
    end

    def vm_inv_to_hashes(inv, _storage_inv, storage_uids, cluster_uids, host_uids, lan_uids)
      result = []
      result_uids = {}
      guest_device_uids = {}
      added_hosts = []
      return result, result_uids, added_hosts if inv.nil?

      inv.each do |vm_inv|
        vm_id = vm_inv.id

        # Skip the place holder template since it does not really exist and does not have a unique ID accross multiple Management Systems
        next if vm_id == '00000000-0000-0000-0000-000000000000'

        template        = vm_inv.href.include?('/templates/')
        raw_power_state = template ? "never" : vm_inv.status

        boot_time = vm_inv.try(:start_time)

        storages = []
        vm_inv.disks.to_miq_a.each do |disk|
          disk.storage_domains.to_miq_a.each do |sd|
            storages << storage_uids[sd.id]
          end
        end
        storages.compact!
        storages.uniq!
        storage = storages.first

        # Determine the cluster
        ems_cluster = cluster_uids[vm_inv.cluster.id]

        # If the VM is running it will have a host name in the data
        # Otherwise if it is assigned to run on a specific host the host ID will be in the placement_policy
        host_id = vm_inv.try(:host).try(:id)
        host_id = vm_inv.try(:placement_policy).try(:hosts).try(:id) if host_id.blank?
        host = host_uids.values.detect { |h| h[:uid_ems] == host_id } unless host_id.blank?

        # If the vm has a host but the refresh does not include it in the "hosts" hash
        if host.blank? && vm_inv.try(:host).present?
          host = partial_host_hash(vm_inv.host, ems_cluster)
          added_hosts << host if host
        end

        host_mor = host_id
        hardware = vm_inv_to_hardware_hash(vm_inv)
        hardware[:disks] = vm_inv_to_disk_hashes(vm_inv, storage_uids)
        hardware[:guest_devices], guest_device_uids[vm_id] = vm_inv_to_guest_device_hashes(vm_inv, lan_uids[host_mor])
        hardware[:networks] = vm_inv_to_network_hashes(vm_inv, guest_device_uids[vm_id])

        ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(vm_inv.href)

        new_result = create_vm_hash(template, ems_ref, vm_inv.id, URI.decode(vm_inv.name))

        additional = {
          :memory_reserve    => vm_memory_reserve(vm_inv),
          :raw_power_state   => raw_power_state,
          :boot_time         => boot_time,
          :connection_state  => 'connected',
          :host              => host,
          :ems_cluster       => ems_cluster,
          :storages          => storages,
          :storage           => storage,
          :operating_system  => vm_inv_to_os_hash(vm_inv),
          :hardware          => hardware,
          :custom_attributes => vm_inv_to_custom_attribute_hashes(vm_inv),
          :snapshots         => vm_inv_to_snapshot_hashes(vm_inv),
        }
        new_result.merge!(additional)

        # Attach to the cluster's default resource pool
        ems_cluster[:ems_children][:resource_pools].first[:ems_children][:vms] << new_result if ems_cluster && !template

        result << new_result
        result_uids[vm_id] = new_result
      end
      return result, result_uids, added_hosts
    end

    def partial_host_hash(partial_host_inv, ems_cluster)
      ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(partial_host_inv.href)
      { :ems_ref => ems_ref, :uid_ems => partial_host_inv.id, :ems_cluster => ems_cluster }
    end

    def create_vm_hash(template, ems_ref, vm_id, name)
      {
        :type        => template ? "ManageIQ::Providers::Redhat::InfraManager::Template" : "ManageIQ::Providers::Redhat::InfraManager::Vm",
        :ems_ref     => ems_ref,
        :ems_ref_obj => ems_ref,
        :uid_ems     => vm_id,
        :vendor      => "redhat",
        :name        => name,
        :location    => "#{vm_id}.ovf",
        :template    => template,
      }
    end

    def vm_inv_to_hardware_hash(inv)
      return nil if inv.nil?

      result = {
        :guest_os   => inv.dig(:os, :type),
        :annotation => inv.try(:description)
      }

      hdw = inv.cpu
      topology = hdw.topology
      result[:cpu_cores_per_socket] = topology.try(:cores) || 1
      result[:cpu_sockets]          = topology.try(:sockets) || 1
      result[:cpu_total_cores]      = result[:cpu_sockets] * result[:cpu_cores_per_socket]

      result[:memory_mb] = inv.memory / 1.megabyte

      result
    end

    def vm_inv_to_guest_device_hashes(inv, lan_uids)
      inv = inv.nics

      result = []
      result_uids = {}
      return result, result_uids if inv.nil?

      inv.to_miq_a.each do |data|
        uid = data.id
        address = data.dig(:mac, :address)
        name = data.name

        lan = lan_uids[data.dig(:network, :id)] unless lan_uids.nil?

        new_result = {
          :uid_ems         => uid,
          :device_name     => name,
          :device_type     => 'ethernet',
          :controller_type => 'ethernet',
          :address         => address,
        }
        new_result[:lan] = lan unless lan.nil?

        result << new_result
        result_uids[uid] = new_result
      end
      return result, result_uids
    end

    def vm_inv_to_network_hashes(inv, guest_device_uids)
      reported_device = inv.respond_to?(:reported_devices) ? inv.reported_devices[0] : nil
      inv_net = reported_device.ips if reported_device
      result = []
      return result if inv_net.nil?

      inv_net.to_miq_a.each do |data|
        new_result = { :ipaddress => data.address }
        result << new_result unless new_result.blank?
      end

      # There is not data to corridnate what IPs go with what networks
      # So if there is only 1 of each link them together.
      if result.length == 1 && guest_device_uids.length == 1
        guest_device = guest_device_uids[guest_device_uids.keys.first]
        guest_device[:network] = result.first unless guest_device.nil?
      end

      # RHV reports hostname for the entire vm and not per specific network interface.
      # Therefore, the hostname will be set for the first nic.
      result[0][:hostname] = inv.fqdn if !result.blank? && inv.respond_to?(:fqdn)
      result
    end

    def vm_inv_to_disk_hashes(inv, storage_uids)
      inv = inv.try(:disks)

      result = []
      return result if inv.nil?
      # RHEV initially orders disks by bootable status then by name. Attempt
      # to use the disk number in the name, if available, as an ordering hint
      # to support the case where a disk is added after initial VM creation.
      inv = inv.to_miq_a.sort_by do |disk|
        match = disk.try(:name).match(/disk[^\d]*(?<index>\d+)/i)
        [disk.try(:bootable) ? 0 : 1, match ? match[:index].to_i : Float::INFINITY, disk.name]
      end.group_by { |d| d.try(:interface) }

      inv.each do |interface, devices|
        devices.each_with_index do |device, index|
          device_type = 'disk'
          storage_domain = device.storage_domains && device.storage_domains.first
          storage_mor = storage_domain && storage_domain.id

          new_result = {
            :device_name     => device.name,
            :device_type     => device_type,
            :controller_type => interface,
            :present         => true,
            :filename        => device.id,
            :location        => index.to_s,
            :size            => device.provisioned_size.to_i,
            :size_on_disk    => device.actual_size.to_i,
            :disk_type       => device.sparse == true ? 'thin' : 'thick',
            :mode            => 'persistent',
            :bootable        => device.try(:bootable)
          }

          new_result[:storage] = storage_uids[storage_mor] unless storage_mor.nil?
          result << new_result
        end
      end

      result
    end

    def vm_inv_to_os_hash(inv)
      guest_os = inv.dig(:os, :type)
      result = {
        # If the data from VC is empty, default to "Other"
        :product_name => guest_os.blank? ? "Other" : guest_os
      }
      result[:system_type] = inv.type unless inv.type.nil?
      result
    end

    def vm_inv_to_snapshot_hashes(inv)
      result = []
      inv = inv.try(:snapshots).to_miq_a.reverse
      return result if inv.nil?

      parent_id = nil
      inv.each_with_index do |snapshot, idx|
        result << snapshot_inv_to_snapshot_hashes(snapshot, idx == inv.length - 1, parent_id)
        parent_id = snapshot.id
      end
      result
    end

    def snapshot_inv_to_snapshot_hashes(inv, current, parent_uid = nil)
      create_time = inv.date.getutc

      # Fix case where blank description comes back as a Hash instead
      name = description = inv.description
      name = "Active Image" if name[0, 13] == '_ActiveImage_'

      result = {
        :uid_ems     => inv.id,
        :uid         => inv.id,
        :parent_uid  => parent_uid,
        :name        => name,
        :description => description,
        :create_time => create_time,
        :current     => current,
      }

      result
    end

    def vm_inv_to_custom_attribute_hashes(inv)
      result = []
      custom_attrs = inv.try(:custom_properties)
      return result if custom_attrs.nil?

      custom_attrs.each do |ca|
        new_result = {
          :section => 'custom_field',
          :name    => ca.name,
          :value   => ca.value.try(:truncate, 255),
          :source  => "VC",
        }
        result << new_result
      end

      result
    end

    require 'ostruct'

    def vm_memory_reserve(vm_inv)
      in_bytes = vm_inv.dig(:memory_policy, :guaranteed)
      in_bytes.nil? ? nil : in_bytes / Numeric::MEGABYTE
    end
  end
end
