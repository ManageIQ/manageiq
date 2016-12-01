module ManageIQ::Providers::Redhat::InfraManager::Refresh::Parse::Strategies
  class HostInventory

    attr_reader :host_inv, :_log

    def initialize(args)
      @host_inv = args[:inv]
      @_log = args[:logger]
    end

    def host_inv_to_hashes(inv, ems_inv, cluster_uids, _storage_uids)
      result = []
      result_uids = {}
      lan_uids = {}
      switch_uids = {}
      guest_device_uids = {}
      scsi_lun_uids = {}
      return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids if inv.nil?

      inv.each do |host_inv|
        host_id = host_inv.id

        hostname = host_inv.address

        # Check connection state and log potential issues
        power_state = host_inv.status#&.state
        if ['down', nil, ''].include?(power_state)
          _log.warn "Host [#{host_id}] connection state is [#{power_state.inspect}].  Inventory data may be missing."
        end

        power_state, connection_state = case power_state
                                        when 'up'             then ['on',         'connected']
                                        when 'maintenance'    then [power_state,  'connected']
                                        when 'down'           then ['off',        'disconnected']
                                        when 'non_responsive' then ['unknown',    'connected']
                                        else [power_state, 'disconnected']
                                        end

        # Remove the domain suffix if it is included in the hostname
        hostname = hostname.split(',').first
        # Get the IP address
        ipaddress = host_inv_to_ip(host_inv, hostname) || host_inv.address

        # Collect the hardware, networking, and scsi inventories
        switches, switch_uids[host_id], lan_uids[host_id] = host_inv_to_switch_hashes(host_inv, ems_inv)

        hardware = host_inv_to_hardware_hash(host_inv)
        hardware[:guest_devices], guest_device_uids[host_id] = host_inv_to_guest_device_hashes(host_inv, switch_uids[host_id], ems_inv)
        hardware[:networks] = host_inv_to_network_hashes(host_inv, guest_device_uids[host_id])

        ipmi_address = nil
        if host_inv.attributes.fetch_path(:power_management, :type).to_s.include?('ipmi')
          ipmi_address = host_inv.attributes.fetch_path(:power_management, :address)
        end

        host_os_version = host_inv&.os&.version
        ems_ref = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(host_inv[:href])
        new_result = {
          :type             => 'ManageIQ::Providers::Redhat::InfraManager::Host',
          :ems_ref          => ems_ref,
          :ems_ref_obj      => ems_ref,
          :name             => host_inv.name || hostname,
          :hostname         => hostname,
          :ipaddress        => ipaddress,
          :uid_ems          => host_inv.id,
          :vmm_vendor       => 'redhat',
          :vmm_product      => host_inv.type,
          :vmm_version      => extract_host_version(host_os_version),
          :vmm_buildnumber  => (host_os_version.build if host_os_version),
          :connection_state => connection_state,
          :power_state      => power_state,
          :operating_system => host_inv_to_os_hash(host_inv, hostname),
          :ems_cluster      => cluster_uids[host_inv&.cluster&.id],
          :hardware         => hardware,
          :switches         => switches,
        }
        new_result[:ipmi_address] = ipmi_address unless ipmi_address.blank?

        result << new_result
        result_uids[host_id] = new_result
      end
      return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids
    end

    def extract_host_version(host_os_version)
      return unless host_os_version && host_os_version.major

      version = host_os_version.major
      version = "#{version}.#{host_os_version.minor}" if host_os_version.minor
      version
    end

    def host_inv_to_ip(inv, hostname = nil)
      _log.debug("IP lookup for host in VIM inventory data...")
      ipaddress = nil
      inv.nics.to_miq_a.each do |nic|
        ip_data = nic.ip
        if !ip_data.nil? && !ip_data.gateway.blank? && !ip_data.address.blank?
          ipaddress = ip_data.address
          break
        end
      end

      unless ipaddress.nil?
        warn_msg = "IP lookup for host in VIM inventory data...Failed."
        if [nil, "localhost", "localhost.localdomain", "127.0.0.1"].include?(hostname)
          _log.warn warn_msg
        else
          _log.warn "#{warn_msg} Falling back to reverse lookup."
          begin
            # IPSocket.getaddress(hostname) is not used because it was appending
            #   a ".com" to the "esxdev001.localdomain" which resolved to a real
            #   internet address. Socket.getaddrinfo does the right thing.
            # TODO: Can this moved to MiqSockUtil?

            # _log.debug "IP lookup by hostname [#{hostname}]..."
            ipaddress = Socket.getaddrinfo(hostname, nil)[0][3]
            _log.debug "IP lookup by hostname [#{hostname}]...Complete: IP found: [#{ipaddress}]"
          rescue => err
            _log.warn "IP lookup by hostname [#{hostname}]...Failed with the following error: #{err}"
          end
        end
      end

      ipaddress
    end

    def host_inv_to_switch_hashes(inv, ems_inv)
      nics = inv.nics

      result = []
      result_uids = {:pnic_id => {}}
      lan_uids    = {}
      return result, result_uids if nics.nil?

      nics.to_miq_a.each do |data|
        network_id = data&.network&.id
        unless network_id.nil?
          network = ems_inv[:network].detect { |n| n[:id] == network_id }
        else
          network_name = data&.network&.name
          cluster_id = inv.attributes.fetch_path(:cluster, :id)
          cluster = ems_inv[:cluster].detect { |c| c[:id] == cluster_id }
          datacenter_id = cluster&.data_center&.id
          network = ems_inv[:network].detect { |n| n[:name] == network_name && n.attributes.fetch_path(:data_center, :id) == datacenter_id }
        end

        tag_value = nil
        unless network.nil?
          uid = network.id
          name = network.name
          tag_value = network.try(:vlan)&.id
        else
          uid = name = network_name unless network_name.nil?
        end

        next if uid.nil?

        lan = {:name => name, :uid_ems => uid, :tag => tag_value}
        lan_uids[uid] = lan
        new_result = {
          :uid_ems => uid,
          :name    => name,

          :lans    => [{:name => name, :uid_ems => uid, :tag => tag_value}]
        }

        result << new_result
        result_uids[uid] = new_result
      end
      return result, result_uids, lan_uids
    end

    def host_inv_to_hardware_hash(inv)
      return nil if inv.nil?

      result = {}

      hdw = inv.cpu
      unless hdw.blank?
        result[:cpu_speed] = hdw.speed
        result[:cpu_type] = hdw.name

        # Value provided by VC is in bytes, need to convert to MB
        memory_total_attr = inv.statistics.to_miq_a.detect { |stat| stat.name == 'memory.total' }
        memory_total = memory_total_attr&.values&.first&.datum
        result[:memory_mb] = memory_total.nil? ? 0 : memory_total.to_i / 1.megabyte

        result[:cpu_cores_per_socket] = hdw&.topology&.cores || 1
        result[:cpu_sockets]          = hdw&.topology&.sockets || 1
        result[:cpu_total_cores]      = result[:cpu_sockets] * result[:cpu_cores_per_socket]
      end

      hw_info = inv.hardware_information
      unless hw_info.blank?
        result[:manufacturer] = hw_info.manufacturer
        result[:model] = hw_info.product_name
      end

      result
    end

    def host_inv_to_guest_device_hashes(inv, switch_uids, ems_inv)
      pnic = inv.nics

      result = []
      result_uids = {}
      return result, result_uids if pnic.nil?
      result_uids[:pnic] = {}
      pnic.to_miq_a.each do |data|
        # Find the switch to which this pnic is connected
        network_id = data&.network&.id
        unless network_id.nil?
          network = ems_inv[:network].detect { |n| n[:id] == network_id }
        else
          network_name = data&.network&.name
          cluster_id = inv&.cluster&.id
          cluster = ems_inv[:cluster].detect { |c| c[:id] == cluster_id }
          datacenter_id = cluster.attributes.fetch_path(:data_center, :id)
          network = ems_inv[:network].detect { |n| n[:name] == network_name && n.attributes.fetch_path(:data_center, :id) == datacenter_id }
        end

        unless network.nil?
          switch_uid = network[:id]
        else
          switch_uid = network_name unless network_name.nil?
        end

        unless switch_uid.nil?
          switch = switch_uids[switch_uid]
        end

        location = nil
        location = $1 if data.name =~ /(\d+)$/
        uid = data.id

        new_result = {
          :uid_ems         => uid,
          :device_name     => data.name,
          :device_type     => 'ethernet',
          :location        => location,
          :present         => true,
          :controller_type => 'ethernet',
        }
        new_result[:switch] = switch unless switch.nil?

        result << new_result
        result_uids[:pnic][uid] = new_result
      end

      return result, result_uids
    end

    def host_inv_to_os_hash(inv, hostname)
      return nil if inv.nil?

      {
        :name         => hostname,
        :product_type => 'linux',
        :product_name => extract_host_os_name(inv),
        :version      => extract_host_os_full_version(inv.os)
      }
    end

    def extract_host_os_full_version(host_os)
      host_os&.version&.full_version
    end

    def host_inv_to_network_hashes(inv, guest_device_uids)
      inv = inv.nics
      result = []
      return result if inv.nil?

      inv.to_miq_a.each do |vnic|
        uid = vnic.id
        guest_device = guest_device_uids.fetch_path(:pnic, uid)

        # Get the ip section
        ip = vnic.ip.presence || {}

        new_result = {
          :description => vnic.name,
          :ipaddress   => ip.address,
          :subnet_mask => ip.netmask,
        }

        result << new_result
        guest_device[:network] = new_result unless guest_device.nil?
      end
      result
    end

    def extract_host_os_name(host_inv)
      host_os = host_inv.os
      host_os && host_os.type || host_inv.type
    end
  end
end
