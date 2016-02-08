require 'miq-uuid'

module ManageIQ::Providers
  module Vmware
    module InfraManager::RefreshParser
      #
      # EMS Inventory Parsing
      #

      def self.ems_inv_to_hashes(inv)
        uids = {}
        result = {:uid_lookup => uids}

        result[:storages], uids[:storages] = storage_inv_to_hashes(inv[:storage])
        result[:clusters], uids[:clusters] = cluster_inv_to_hashes(inv[:cluster])

        result[:hosts], uids[:hosts], uids[:clusters_by_host], uids[:lans], uids[:switches], uids[:guest_devices], uids[:scsi_luns] = host_inv_to_hashes(inv[:host], inv, uids[:storages], uids[:clusters])
        result[:vms], uids[:vms] = vm_inv_to_hashes(inv[:vm], inv[:storage], uids[:storages], uids[:hosts], uids[:clusters_by_host], uids[:lans])

        result[:folders], uids[:folders] = inv_to_ems_folder_hashes(inv)
        result[:resource_pools], uids[:resource_pools] = rp_inv_to_hashes(inv[:rp])

        result[:customization_specs] = customization_spec_inv_to_hashes(inv[:customization_specs]) if inv.key?(:customization_specs)

        link_ems_metadata(result, inv)
        link_root_folder(result)
        set_hidden_folders(result)
        set_default_rps(result)

        result
      end

      def self.storage_inv_to_hashes(inv)
        result = []
        result_uids = {:storage_id => {}}
        return result, result_uids if inv.nil?

        inv.each do |mor, storage_inv|
          mor = storage_inv['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          summary = storage_inv["summary"]
          next if summary.nil?

          capability = storage_inv["capability"]

          loc = uid = normalize_storage_uid(storage_inv)

          new_result = {
            :ems_ref            => mor,
            :ems_ref_obj        => mor,
            :name               => summary["name"],
            :store_type         => summary["type"].to_s.upcase,
            :total_space        => summary["capacity"],
            :free_space         => summary["freeSpace"],
            :uncommitted        => summary["uncommitted"],
            :multiplehostaccess => summary["multipleHostAccess"].to_s.downcase == "true",
            :location           => loc,
          }

          unless capability.nil?
            new_result.merge!(
              :directory_hierarchy_supported => capability['directoryHierarchySupported'].blank? ? nil : capability['directoryHierarchySupported'].to_s.downcase == 'true',
              :thin_provisioning_supported   => capability['perFileThinProvisioningSupported'].blank? ? nil : capability['perFileThinProvisioningSupported'].to_s.downcase == 'true',
              :raw_disk_mappings_supported   => capability['rawDiskMappingsSupported'].blank? ? nil : capability['rawDiskMappingsSupported'].to_s.downcase == 'true'
            )
          end

          result << new_result
          result_uids[mor] = new_result
          result_uids[:storage_id][uid] = new_result
        end
        return result, result_uids
      end

      def self.host_inv_to_hashes(inv, ems_inv, storage_uids, cluster_uids)
        result = []
        result_uids = {}
        cluster_uids_by_host = {}
        lan_uids = {}
        switch_uids = {}
        guest_device_uids = {}
        scsi_lun_uids = {}
        return result, result_uids, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids if inv.nil?

        inv.each do |mor, host_inv|
          mor = host_inv['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          config = host_inv["config"]
          dns_config = config.fetch_path('network', 'dnsConfig') unless config.nil?
          hostname = dns_config["hostName"] unless dns_config.nil?
          domain_name = dns_config["domainName"] unless dns_config.nil?

          summary = host_inv["summary"]
          product = summary.fetch_path('config', 'product') unless summary.nil?

          # Check connection state and log potential issues
          connection_state = summary.fetch_path("runtime", "connectionState") unless summary.nil?
          maintenance_mode = summary.fetch_path("runtime", "inMaintenanceMode") unless summary.nil?
          if ['disconnected', 'notResponding', nil, ''].include?(connection_state)
            _log.warn "Host [#{mor}] connection state is [#{connection_state.inspect}].  Inventory data may be missing."
          end

          # Determine if the data from VC is valid.
          invalid, err = if config.nil? || product.nil? || summary.nil?
                           type = ['config', 'product', 'summary'].find_all { |t| eval(t).nil? }.join(", ")
                           [true, "Missing configuration for Host [#{mor}]: [#{type}]."]
                         elsif hostname.blank?
                           [true, "Missing hostname information for Host [#{mor}]: dnsConfig: #{dns_config.inspect}."]
                         elsif domain_name.blank?
                           # Use the name or the summary-config-name as the hostname if either appears to be a FQDN
                           fqdn = host_inv["name"]
                           fqdn = summary.fetch_path('config', 'name') unless fqdn =~ /^#{hostname}\./
                           hostname = fqdn if fqdn =~ /^#{hostname}\./
                           false
                         else
                           hostname = "#{hostname}.#{domain_name}"
                           false
                         end

          if invalid
            _log.warn "#{err} Skipping."

            new_result = {
              :invalid     => true,
              :ems_ref     => mor,
              :ems_ref_obj => mor
            }
            result << new_result
            result_uids[mor] = new_result
            next
          end

          # Remove the domain suffix if it is included in the hostname
          hostname = hostname.split(',').first
          # Get the IP address
          ipaddress = host_inv_to_ip(host_inv, hostname) || hostname

          vendor = product["vendor"].split(",").first.to_s.downcase
          vendor = "unknown" unless Host::VENDOR_TYPES.include?(vendor)

          product_name = product["name"].nil? ? nil : product["name"].to_s.gsub(/^VMware\s*/i, "")

          # Collect the hardware, networking, and scsi inventories
          switches, switch_uids[mor] = host_inv_to_switch_hashes(host_inv)
          lans, lan_uids[mor] = host_inv_to_lan_hashes(host_inv, switch_uids[mor])

          hardware = host_inv_to_hardware_hash(host_inv)
          hardware[:guest_devices], guest_device_uids[mor] = host_inv_to_guest_device_hashes(host_inv, switch_uids[mor])
          hardware[:networks] = host_inv_to_network_hashes(host_inv, guest_device_uids[mor])

          scsi_luns, scsi_lun_uids[mor] = host_inv_to_scsi_lun_hashes(host_inv)
          scsi_targets = host_inv_to_scsi_target_hashes(host_inv, guest_device_uids[mor][:storage], scsi_lun_uids[mor])

          # Collect the resource pools inventory
          parent_type, parent_mor, parent_data = host_parent_resource(mor, ems_inv)
          if parent_type == :host_res
            rp_uids = get_mors(parent_data, "resourcePool")
            cluster_uids_by_host[mor] = nil
          else
            rp_uids = []
            cluster_uids_by_host[mor] = cluster_uids[parent_mor]
          end

          # Collect failover host information if in a cluster
          failover = nil
          if parent_type == :cluster
            failover_hosts = parent_data.fetch_path("configuration", "dasConfig", "admissionControlPolicy", "failoverHosts")
            failover = failover_hosts && failover_hosts.include?(mor)
          end

          # Link up the storages
          storages = get_mors(host_inv, 'datastore').collect { |s| storage_uids[s] }.compact

          # Find the host->storage mount info
          host_storages = host_inv_to_host_storages_hashes(host_inv, ems_inv[:storage], storage_uids)

          # Store the host 'name' value as uid_ems to use as the lookup value with MiqVim
          uid_ems = summary.nil? ? nil : summary.fetch_path('config', 'name')

          # Get other information
          asset_tag = service_tag = nil
          host_inv.fetch_path("hardware", "systemInfo", "otherIdentifyingInfo").to_miq_a.each do |info|
            next unless info.kind_of?(Hash)

            value = info["identifierValue"].to_s.strip
            value = nil if value.blank?

            case info.fetch_path("identifierType", "key")
            when "AssetTag"   then asset_tag   = value
            when "ServiceTag" then service_tag = value
            end
          end

          new_result = {
            :type             => %w(esx esxi).include?(product_name.to_s.downcase) ? "ManageIQ::Providers::Vmware::InfraManager::HostEsx" : "ManageIQ::Providers::Vmware::InfraManager::Host",
            :ems_ref          => mor,
            :ems_ref_obj      => mor,
            :name             => hostname,
            :hostname         => hostname,
            :ipaddress        => ipaddress,
            :uid_ems          => uid_ems,
            :vmm_vendor       => vendor,
            :vmm_version      => product["version"],
            :vmm_product      => product_name,
            :vmm_buildnumber  => product["build"],
            :connection_state => connection_state,
            :power_state      => connection_state != "connected" ? "off" : (maintenance_mode.to_s.downcase == "true" ? "maintenance" : "on"),
            :admin_disabled   => config["adminDisabled"].to_s.downcase == "true",
            :maintenance      => maintenance_mode.to_s.downcase == "true",
            :asset_tag        => asset_tag,
            :service_tag      => service_tag,
            :failover         => failover,
            :hyperthreading   => config.fetch_path("hyperThread", "active").to_s.downcase == "true",

            :ems_cluster      => cluster_uids_by_host[mor],
            :operating_system => host_inv_to_os_hash(host_inv, hostname),
            :system_services  => host_inv_to_system_service_hashes(host_inv),

            :hardware         => hardware,
            :switches         => switches,
            :storages         => storages,
            :host_storages    => host_storages,

            :child_uids       => rp_uids,
          }
          result << new_result
          result_uids[mor] = new_result
        end
        return result, result_uids, cluster_uids_by_host, lan_uids, switch_uids, guest_device_uids, scsi_lun_uids
      end

      def self.host_inv_to_ip(inv, hostname = nil)
        _log.debug("IP lookup for host in VIM inventory data...")
        ipaddress = nil

        default_gw = inv.fetch_path("config", "network", "ipRouteConfig", "defaultGateway")
        unless default_gw.blank?
          require 'ipaddr'
          default_gw = IPAddr.new(default_gw)

          network = inv.fetch_path("config", "network")
          vnics   = network['consoleVnic'].to_miq_a + network['vnic'].to_miq_a

          vnics.each do |vnic|
            ip = vnic.fetch_path("spec", "ip", "ipAddress")
            subnet_mask = vnic.fetch_path("spec", "ip", "subnetMask")
            next if ip.blank? || subnet_mask.blank?

            if default_gw.mask(subnet_mask).include?(ip)
              ipaddress = ip
              _log.debug("IP lookup for host in VIM inventory data...Complete: IP found: [#{ipaddress}]")
              break
            end
          end
        end

        if ipaddress.nil?
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

              _log.debug "IP lookup by hostname [#{hostname}]..."
              ipaddress = Socket.getaddrinfo(hostname, nil)[0][3]
              _log.debug "IP lookup by hostname [#{hostname}]...Complete: IP found: [#{ipaddress}]"
            rescue => err
              _log.warn "IP lookup by hostname [#{hostname}]...Failed with the following error: #{err}"
            end
          end
        end

        ipaddress
      end

      def self.host_inv_to_os_hash(inv, hostname)
        inv = inv.fetch_path('summary', 'config', 'product')
        return nil if inv.nil?

        result = {:name => hostname}
        result[:product_name] = inv["name"].gsub(/^VMware\s*/i, "") unless inv["name"].blank?
        result[:version] = inv["version"] unless inv["version"].blank?
        result[:build_number] = inv["build"] unless inv["build"].blank?
        result[:product_type] = inv["osType"] unless inv["osType"].blank?
        result
      end

      def self.host_inv_to_hardware_hash(inv)
        console = inv.fetch_path('config', 'consoleReservation')
        inv = inv['summary']
        return nil if inv.nil?

        result = {}

        hdw = inv["hardware"]
        unless hdw.blank?
          result[:cpu_speed] = hdw["cpuMhz"] unless hdw["cpuMhz"].blank?
          result[:cpu_type] = hdw["cpuModel"] unless hdw["cpuModel"].blank?
          result[:manufacturer] = hdw["vendor"] unless hdw["vendor"].blank?
          result[:model] = hdw["model"] unless hdw["model"].blank?
          result[:number_of_nics] = hdw["numNics"] unless hdw["numNics"].blank?

          # Value provided by VC is in bytes, need to convert to MB
          result[:memory_mb] = is_numeric?(hdw["memorySize"]) ? (hdw["memorySize"].to_f / 1.megabyte).round : nil
          unless console.nil?
            result[:memory_console] = is_numeric?(console["serviceConsoleReserved"]) ? (console["serviceConsoleReserved"].to_f / 1048576).round : nil
          end

          result[:cpu_sockets]     = hdw["numCpuPkgs"] unless hdw["numCpuPkgs"].blank?
          result[:cpu_total_cores] = hdw["numCpuCores"] unless hdw["numCpuCores"].blank?
          # Calculate the number of cores per socket by dividing total numCpuCores by numCpuPkgs
          result[:cpu_cores_per_socket] = (result[:cpu_total_cores].to_f / result[:cpu_sockets].to_f).to_i unless hdw["numCpuCores"].blank? || hdw["numCpuPkgs"].blank?
        end

        config = inv["config"]
        unless config.blank?
          value = config.fetch_path("product", "name")
          unless value.blank?
            value = value.to_s.gsub(/^VMware\s*/i, "")
            result[:guest_os] = value
            result[:guest_os_full_name] = value
          end

          result[:vmotion_enabled] = config["vmotionEnabled"].to_s.downcase == "true" unless config["vmotionEnabled"].blank?
        end

        quickStats = inv["quickStats"]
        unless quickStats.blank?
          result[:cpu_usage] = quickStats["overallCpuUsage"] unless quickStats["overallCpuUsage"].blank?
          result[:memory_usage] = quickStats["overallMemoryUsage"] unless quickStats["overallMemoryUsage"].blank?
        end

        result
      end

      def self.host_inv_to_switch_hashes(inv)
        inv = inv.fetch_path('config', 'network')

        result = []
        result_uids = {:pnic_id => {}}
        return result, result_uids if inv.nil?

        inv['vswitch'].to_miq_a.each do |data|
          name = uid = data['name']
          pnics = data['pnic'].to_miq_a

          security_policy = data.fetch_path('spec', 'policy', 'security') || {}

          new_result = {
            :uid_ems           => uid,
            :name              => name,
            :ports             => data['numPorts'],

            :allow_promiscuous => security_policy['allowPromiscuous'].nil? ? nil : security_policy['allowPromiscuous'].to_s.downcase == 'true',
            :forged_transmits  => security_policy['forgedTransmits'].nil? ? nil : security_policy['forgedTransmits'].to_s.downcase == 'true',
            :mac_changes       => security_policy['macChanges'].nil? ? nil : security_policy['macChanges'].to_s.downcase == 'true',

            :lans              => []
          }

          result << new_result
          result_uids[uid] = new_result

          pnics.each { |pnic| result_uids[:pnic_id][pnic] = new_result unless pnic.blank? }
        end
        return result, result_uids
      end

      def self.host_inv_to_lan_hashes(inv, switch_uids)
        inv = inv.fetch_path('config', 'network')

        result = []
        result_uids = {}
        return result, result_uids if inv.nil?

        inv['portgroup'].to_miq_a.each do |data|
          spec = data['spec']
          next if spec.nil?

          # Find the switch to which this lan is connected
          switch = switch_uids[spec['vswitchName']]
          next if switch.nil?

          name = uid = spec['name']

          security_policy = data.fetch_path('spec', 'policy', 'security') || {}
          computed_security_policy = data.fetch_path('computedPolicy', 'security') || {}

          new_result = {
            :uid_ems                    => uid,
            :name                       => name,
            :tag                        => spec['vlanId'].to_s,

            :allow_promiscuous          => security_policy['allowPromiscuous'].nil? ? nil : security_policy['allowPromiscuous'].to_s.downcase == 'true',
            :forged_transmits           => security_policy['forgedTransmits'].nil? ? nil : security_policy['forgedTransmits'].to_s.downcase == 'true',
            :mac_changes                => security_policy['macChanges'].nil? ? nil : security_policy['macChanges'].to_s.downcase == 'true',

            :computed_allow_promiscuous => computed_security_policy['allowPromiscuous'].nil? ? nil : computed_security_policy['allowPromiscuous'].to_s.downcase == 'true',
            :computed_forged_transmits  => computed_security_policy['forgedTransmits'].nil? ? nil : computed_security_policy['forgedTransmits'].to_s.downcase == 'true',
            :computed_mac_changes       => computed_security_policy['macChanges'].nil? ? nil : computed_security_policy['macChanges'].to_s.downcase == 'true',
          }
          result << new_result
          result_uids[uid] = new_result
          switch[:lans] << new_result
        end
        return result, result_uids
      end

      def self.host_inv_to_guest_device_hashes(inv, switch_uids)
        inv = inv['config']

        result = []
        result_uids = {}
        return result, result_uids if inv.nil?

        network = inv["network"]
        storage = inv["storageDevice"]
        return result, result_uids if network.nil? && storage.nil?

        result_uids[:pnic] = {}
        unless network.nil?
          network['pnic'].to_miq_a.each do |data|
            # Find the switch to which this pnic is connected
            switch = switch_uids[:pnic_id][data['key']]

            name = uid = data['device']

            new_result = {
              :uid_ems         => uid,
              :device_name     => name,
              :device_type     => 'ethernet',
              :location        => data['pci'],
              :present         => true,
              :controller_type => 'ethernet',
              :address         => data['mac']
            }
            new_result[:switch] = switch unless switch.nil?

            result << new_result
            result_uids[:pnic][uid] = new_result
          end
        end

        result_uids[:storage] = {:adapter_id => {}}
        unless storage.nil?
          storage['hostBusAdapter'].to_miq_a.each do |data|
            name = uid = data['device']
            adapter = data['key']
            chap_auth_enabled = data.fetch_path('authenticationProperties', 'chapAuthEnabled')

            new_result = {
              :uid_ems           => uid,
              :device_name       => name,
              :device_type       => 'storage',
              :present           => true,

              :iscsi_name        => data['iScsiName'].blank? ? nil : data['iScsiName'],
              :iscsi_alias       => data['iScsiAlias'].blank? ? nil : data['iScsiAlias'],
              :location          => data['pci'].blank? ? nil : data['pci'],
              :model             => data['model'].blank? ? nil : data['model'],

              :chap_auth_enabled => chap_auth_enabled.blank? ? nil : chap_auth_enabled.to_s.downcase == "true"
            }

            new_result[:controller_type] = case data.xsiType.to_s.split("::").last
                                           when 'HostBlockHba'        then 'Block'
                                           when 'HostFibreChannelHba' then 'Fibre'
                                           when 'HostInternetScsiHba' then 'iSCSI'
                                           when 'HostParallelScsiHba' then 'SCSI'
                                           when 'HostBusAdapter'      then 'HBA'
                                           end

            result << new_result
            result_uids[:storage][uid] = new_result
            result_uids[:storage][:adapter_id][adapter] = new_result
          end
        end

        return result, result_uids
      end

      def self.host_inv_to_network_hashes(inv, guest_device_uids)
        inv = inv.fetch_path('config', 'network')
        result = []
        return result if inv.nil?

        vnics = inv['consoleVnic'].to_miq_a + inv['vnic'].to_miq_a
        vnics.to_miq_a.each do |vnic|
          # Find the pnic to which this service console is connected
          port_key = vnic['port']
          portgroup = inv['portgroup'].to_miq_a.find { |pg| pg['port'].to_miq_a.find { |p| p['key'] == port_key } }
          next if portgroup.nil?

          vswitch_key = portgroup['vswitch']
          vswitch = inv['vswitch'].to_miq_a.find { |v| v['key'] == vswitch_key }
          next if vswitch.nil?

          pnic_key = vswitch['pnic'].to_miq_a[0]
          pnic = inv['pnic'].to_miq_a.find { |p| p['key'] == pnic_key }
          next if pnic.nil?

          uid = pnic['device']
          guest_device = guest_device_uids.fetch_path(:pnic, uid)

          # Get the ip section
          ip = vnic.fetch_path('spec', 'ip')
          next if ip.nil?

          new_result = {
            :description  => uid,
            :dhcp_enabled => ip['dhcp'].to_s.downcase == 'true',
            :ipaddress    => ip['ipAddress'],
            :subnet_mask  => ip['subnetMask'],
          }

          result << new_result
          guest_device[:network] = new_result unless guest_device.nil?
        end
        result
      end

      def self.host_inv_to_scsi_lun_hashes(inv)
        inv = inv.fetch_path('config', 'storageDevice')

        result = []
        result_uids = {}
        return result, result_uids if inv.nil?

        inv['scsiLun'].to_miq_a.each do |data|
          new_result = {
            :uid_ems        => data['uuid'],

            :canonical_name => data['canonicalName'].blank? ? nil : data['canonicalName'],
            :lun_type       => data['lunType'].blank? ? nil : data['lunType'],
            :device_name    => data['deviceName'].blank? ? nil : data['deviceName'],
            :device_type    => data['deviceType'].blank? ? nil : data['deviceType'],
          }

          # :lun will be set later when we link to scsi targets

          cap = data['capacity']
          if cap.nil?
            new_result[:block] = new_result[:block_size] = new_result[:capacity] = nil
          else
            block = cap['block'].blank? ? nil : cap['block']
            block_size = cap['blockSize'].blank? ? nil : cap['blockSize']

            new_result[:block] = block
            new_result[:block_size] = block_size
            new_result[:capacity] = (block.nil? || block_size.nil?) ? nil : ((block.to_i * block_size.to_i) / 1024)
          end

          result << new_result
          result_uids[data['key']] = new_result
        end

        return result, result_uids
      end

      def self.host_inv_to_scsi_target_hashes(inv, guest_device_uids, scsi_lun_uids)
        inv = inv.fetch_path('config', 'storageDevice', 'scsiTopology', 'adapter')

        result = []
        return result if inv.nil?

        inv.to_miq_a.each do |adapter|
          adapter['target'].to_miq_a.each do |data|
            target = uid = data['target'].to_s

            new_result = {
              :uid_ems => uid,
              :target  => target
            }

            transport = data['transport']
            if transport.nil?
              new_result[:iscsi_name], new_result[:iscsi_alias], new_result[:address] = nil
            else
              new_result[:iscsi_name] = transport['iScsiName'].blank? ? nil : transport['iScsiName']
              new_result[:iscsi_alias] = transport['iScsiAlias'].blank? ? nil : transport['iScsiAlias']
              new_result[:address] = transport['address'].blank? ? nil : transport['address']
            end

            # Link the scsi target to the bus adapter
            guest_device = guest_device_uids[:adapter_id][adapter['adapter']]
            unless guest_device.nil?
              guest_device[:miq_scsi_targets] ||= []
              guest_device[:miq_scsi_targets] << new_result
            end

            # Link the scsi target to the scsi luns
            data['lun'].to_miq_a.each do |l|
              # We dup here so that later saving of ids doesn't cause a clash
              # TODO: Change this if we get to a better normalized structure in
              #   the database.
              lun = scsi_lun_uids[l['scsiLun']].dup
              unless lun.nil?
                lun[:lun] = l['lun'].to_s

                new_result[:miq_scsi_luns] ||= []
                new_result[:miq_scsi_luns] << lun
              end
            end

            result << new_result
          end
        end
        result
      end

      def self.host_inv_to_system_service_hashes(inv)
        inv = inv.fetch_path('config', 'service')

        result = []
        return result if inv.nil?

        inv['service'].to_miq_a.each do |data|
          result << {
            :name         => data['key'],
            :display_name => data['label'],
            :running      => data['running'].to_s == 'true',
          }
        end
        result
      end

      def self.host_inv_to_host_storages_hashes(inv, storage_inv, storage_uids)
        result = []

        storage_inv.each do |s_mor, s_inv|
          # Find the DatastoreHostMount object for this host
          host_mount = Array.wrap(s_inv["host"]).detect { |host| host["key"] == inv["MOR"] }
          next if host_mount.nil?

          read_only = host_mount.fetch_path("mountInfo", "accessMode") == "readOnly"

          result << {
            :storage   => storage_uids[s_mor],
            :read_only => read_only
          }
        end

        result
      end

      def self.vm_inv_to_hashes(inv, storage_inv, storage_uids, host_uids, cluster_uids_by_host, lan_uids)
        result = []
        result_uids = {}
        guest_device_uids = {}
        return result, result_uids if inv.nil?

        inv.each do |mor, vm_inv|
          mor = vm_inv['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          summary = vm_inv["summary"]
          summary_config = summary["config"] unless summary.nil?
          pathname = summary_config["vmPathName"] unless summary_config.nil?

          config = vm_inv["config"]

          # Determine if the data from VC is valid.
          invalid, err = if summary_config.nil? || config.nil?
                           type = ['summary_config', 'config'].find_all { |t| eval(t).nil? }.join(", ")
                           [true, "Missing configuration for VM [#{mor}]: #{type}."]
                         elsif summary_config["uuid"].blank?
                           [true, "Missing UUID for VM [#{mor}]."]
                         elsif pathname.blank?
                           _log.debug "vmPathname class: [#{pathname.class}] inspect: [#{pathname.inspect}]"
                           [true, "Missing pathname location for VM [#{mor}]."]
                         else
                           false
                         end

          if invalid
            _log.warn "#{err} Skipping."

            new_result = {
              :invalid     => true,
              :ems_ref     => mor,
              :ems_ref_obj => mor
            }
            result << new_result
            result_uids[mor] = new_result
            next
          end

          runtime         = summary['runtime']
          template        = summary_config["template"].to_s.downcase == "true"
          raw_power_state = template ? "never" : runtime['powerState']

          begin
            storage_name, location = VmOrTemplate.repository_parse_path(pathname)
          rescue => err
            _log.warn("Warning: [#{err.message}]")
            _log.debug("Problem processing location for VM [#{summary_config["name"]}] location: [#{pathname}]")
            location = VmOrTemplate.location2uri(pathname)
          end

          affinity_set = config.fetch_path('cpuAffinity', 'affinitySet')
          # The affinity_set will be an array of integers if set
          cpu_affinity = nil
          cpu_affinity = affinity_set.kind_of?(Array) ? affinity_set.join(",") : affinity_set.to_s if affinity_set

          tools_status = summary.fetch_path('guest', 'toolsStatus')
          tools_status = nil if tools_status.blank?
          # tools_installed = case tools_status
          # when 'toolsNotRunning', 'toolsOk', 'toolsOld' then true
          # when 'toolsNotInstalled' then false
          # when nil then nil
          # else false
          # end

          boot_time = runtime['bootTime'].blank? ? nil : runtime['bootTime']

          standby_act = nil
          power_options = config["defaultPowerOps"]
          unless power_options.blank?
            standby_act = power_options["standbyAction"] if power_options["standbyAction"]
            # Other possible keys to look at:
            #   defaultPowerOffType, defaultResetType, defaultSuspendType
            #   powerOffType, resetType, suspendType
          end

          # Other items to possibly include:
          #   boot_delay = config.fetch_path("bootOptions", "bootDelay")
          #   virtual_mmu_usage = config.fetch_path("flags", "virtualMmuUsage")

          # Collect the reservation information
          resource_config = vm_inv["resourceConfig"]
          memory = resource_config && resource_config["memoryAllocation"]
          cpu    = resource_config && resource_config["cpuAllocation"]

          # Collect the storages and hardware inventory
          storages = get_mors(vm_inv, 'datastore').collect { |s| storage_uids[s] }.compact

          host_mor = runtime['host']
          hardware = vm_inv_to_hardware_hash(vm_inv)
          hardware[:disks] = vm_inv_to_disk_hashes(vm_inv, storage_uids)
          hardware[:guest_devices], guest_device_uids[mor] = vm_inv_to_guest_device_hashes(vm_inv, lan_uids[host_mor])
          hardware[:networks] = vm_inv_to_network_hashes(vm_inv, guest_device_uids[mor])
          uid = hardware[:bios]

          new_result = {
            :type                  => template ? ManageIQ::Providers::Vmware::InfraManager::Template.name : ManageIQ::Providers::Vmware::InfraManager::Vm.name,
            :ems_ref               => mor,
            :ems_ref_obj           => mor,
            :uid_ems               => uid,
            :name                  => URI.decode(summary_config["name"]),
            :vendor                => "vmware",
            :raw_power_state       => raw_power_state,
            :location              => location,
            :tools_status          => tools_status,
            :boot_time             => boot_time,
            :standby_action        => standby_act,
            :connection_state      => runtime['connectionState'],
            :cpu_affinity          => cpu_affinity,
            :template              => template,
            :linked_clone          => vm_inv_to_linked_clone(vm_inv),
            :fault_tolerance       => vm_inv_to_fault_tolerance(vm_inv),

            :memory_reserve        => memory && memory["reservation"],
            :memory_reserve_expand => memory && memory["expandableReservation"].to_s.downcase == "true",
            :memory_limit          => memory && memory["limit"],
            :memory_shares         => memory && memory.fetch_path("shares", "shares"),
            :memory_shares_level   => memory && memory.fetch_path("shares", "level"),

            :cpu_reserve           => cpu && cpu["reservation"],
            :cpu_reserve_expand    => cpu && cpu["expandableReservation"].to_s.downcase == "true",
            :cpu_limit             => cpu && cpu["limit"],
            :cpu_shares            => cpu && cpu.fetch_path("shares", "shares"),
            :cpu_shares_level      => cpu && cpu.fetch_path("shares", "level"),

            :host                  => host_uids[host_mor],
            :ems_cluster           => cluster_uids_by_host[host_mor],
            :storages              => storages,
            :storage               => storage_uids[:storage_id][normalize_vm_storage_uid(vm_inv, storage_inv)],
            :operating_system      => vm_inv_to_os_hash(vm_inv),
            :hardware              => hardware,
            :custom_attributes     => vm_inv_to_custom_attribute_hashes(vm_inv),
            :snapshots             => vm_inv_to_snapshot_hashes(vm_inv),
          }

          result << new_result
          result_uids[mor] = new_result
        end
        return result, result_uids
      end

      # The next 3 methods determine shared VMs (linked clones or fault tolerance).
      # Information found at http://www.vmdev.info/?p=546
      def self.vm_inv_to_shared(inv)
        unshared  = inv.fetch_path("summary", "storage", "unshared")
        committed = inv.fetch_path("summary", "storage", "committed")
        unshared.nil? || committed.nil? ? nil : unshared.to_i != committed.to_i
      end

      def self.vm_inv_to_linked_clone(inv)
        vm_inv_to_shared(inv) && inv.fetch_path("summary", "config", "ftInfo", "instanceUuids").to_miq_a.length <= 1
      end

      def self.vm_inv_to_fault_tolerance(inv)
        vm_inv_to_shared(inv) && inv.fetch_path("summary", "config", "ftInfo", "instanceUuids").to_miq_a.length > 1
      end

      def self.vm_inv_to_os_hash(inv)
        inv = inv.fetch_path('summary', 'config')
        return nil if inv.nil?

        result = {
          # If the data from VC is empty, default to "Other"
          :product_name => inv["guestFullName"].blank? ? "Other" : inv["guestFullName"]
        }
        result
      end

      def self.vm_inv_to_hardware_hash(inv)
        config = inv['config']
        inv = inv.fetch_path('summary', 'config')
        return nil if inv.nil?

        result = {
          # Downcase and strip off the word "guest" to match the value stored in the .vmx config file.
          :guest_os           => inv["guestId"].blank? ? "Other" : inv["guestId"].to_s.downcase.chomp("guest"),

          # If the data from VC is empty, default to "Other"
          :guest_os_full_name => inv["guestFullName"].blank? ? "Other" : inv["guestFullName"]
        }

        bios = MiqUUID.clean_guid(inv["uuid"]) || inv["uuid"]
        result[:bios] = bios unless bios.blank?

        if inv["numCpu"].present?
          result[:cpu_total_cores]      = inv["numCpu"].to_i

          # cast numCoresPerSocket to an integer so that we can check for nil and 0
          cpu_cores_per_socket          = config.try(:fetch_path, "hardware", "numCoresPerSocket").to_i
          result[:cpu_cores_per_socket] = (cpu_cores_per_socket.zero?) ? 1 : cpu_cores_per_socket
          result[:cpu_sockets]          = result[:cpu_total_cores] / result[:cpu_cores_per_socket]
        end

        result[:annotation] = inv["annotation"] unless inv["annotation"].blank?
        result[:memory_mb] = inv["memorySizeMB"] unless inv["memorySizeMB"].blank?
        result[:virtual_hw_version] = config['version'].to_s.split('-').last if config && config['version']

        result
      end

      def self.vm_inv_to_guest_device_hashes(inv, lan_uids)
        inv = inv.fetch_path('config', 'hardware', 'device')

        result = []
        result_uids = {}
        return result, result_uids if inv.nil?

        inv.to_miq_a.find_all { |d| d.key?('macAddress') }.each do |data|
          uid = address = data['macAddress']
          name = data.fetch_path('deviceInfo', 'label')

          lan = lan_uids[data.fetch_path('backing', 'deviceName')] unless lan_uids.nil?

          new_result = {
            :uid_ems         => uid,
            :device_name     => name,
            :device_type     => 'ethernet',
            :controller_type => 'ethernet',
            :present         => data.fetch_path('connectable', 'connected').to_s.downcase == 'true',
            :start_connected => data.fetch_path('connectable', 'startConnected').to_s.downcase == 'true',
            :address         => address,
          }
          new_result[:lan] = lan unless lan.nil?

          result << new_result
          result_uids[uid] = new_result
        end
        return result, result_uids
      end

      def self.vm_inv_to_disk_hashes(inv, storage_uids)
        inv = inv.fetch_path('config', 'hardware', 'device')

        result = []
        return result if inv.nil?

        inv = inv.to_miq_a
        inv.each do |device|
          case device.xsiType
          when 'VirtualDisk'   then device_type = 'disk'
          when 'VirtualFloppy' then device_type = 'floppy'
          when 'VirtualCdrom'  then device_type = 'cdrom'
          else next
          end

          backing = device['backing']
          device_type << (backing['fileName'].nil? ? "-raw" : "-image") if device_type == 'cdrom'

          controller = inv.detect { |d| d['key'] == device['controllerKey'] }
          controller_type = case controller.xsiType
                            when /IDE/ then 'ide'
                            when /SIO/ then 'sio'
                            else 'scsi'
                            end

          storage_mor = backing['datastore']

          new_result = {
            :device_name     => device.fetch_path('deviceInfo', 'label'),
            :device_type     => device_type,
            :controller_type => controller_type,
            :present         => true,
            :filename        => backing['fileName'] || backing['deviceName'],
            :location        => "#{controller['busNumber']}:#{device['unitNumber']}",
          }

          if device_type == 'disk'
            new_result.merge!(
              :size => device['capacityInKB'].to_i.kilobytes,
              :mode => backing['diskMode']
            )
            new_result[:disk_type] = if backing.key?('compatibilityMode')
                                       "rdm-#{backing['compatibilityMode'].to_s[0...-4]}"  # physicalMode or virtualMode
                                     else
                                       (backing['thinProvisioned'].to_s.downcase == 'true') ? 'thin' : 'thick'
                                     end
          else
            new_result[:start_connected] = device.fetch_path('connectable', 'startConnected').to_s.downcase == 'true'
          end

          new_result[:storage] = storage_uids[storage_mor] unless storage_mor.nil?

          result << new_result
        end

        result
      end

      def self.vm_inv_to_network_hashes(inv, guest_device_uids)
        inv_guest = inv.fetch_path('summary', 'guest')
        inv_net = inv.fetch_path('guest', 'net')

        result = []
        return result if inv_guest.nil? || inv_net.nil?

        hostname = inv_guest['hostName'].blank? ? nil : inv_guest['hostName']
        guest_ip = inv_guest['ipAddress'].blank? ? nil : inv_guest['ipAddress']
        return result if hostname.nil? && guest_ip.nil?

        inv_net.to_miq_a.each do |data|
          ipv4, ipv6 = data['ipAddress'].to_miq_a.compact.collect(&:to_s).sort.partition { |ip| ip =~ /([0-9]{1,3}\.){3}[0-9]{1,3}/ }
          ipv4 << nil if ipv4.empty?
          ipaddresses = ipv4.zip_stretched(ipv6)

          guest_device = guest_device_uids[data['macAddress']]

          ipaddresses.each do |ipaddress, ipv6address|
            new_result = {
              :hostname => hostname
            }
            new_result[:ipaddress] = ipaddress unless ipaddress.nil?
            new_result[:ipv6address] = ipv6address unless ipv6address.nil?

            result << new_result
            guest_device[:network] = new_result unless guest_device.nil?
          end
        end

        result
      end

      def self.vm_inv_to_custom_attribute_hashes(inv)
        custom_values = inv.fetch_path('summary', 'customValue')
        available_fields = inv['availableField']

        result = []
        return result if custom_values.nil? || available_fields.nil?

        key_to_name = {}
        available_fields.each { |af| key_to_name[af['key']] = af['name'] }
        custom_values.each do |cv|
          new_result = {
            :section => 'custom_field',
            :name    => key_to_name[cv['key']],
            :value   => cv['value'],
            :source  => "VC",
          }
          result << new_result
        end

        result
      end

      def self.vm_inv_to_snapshot_hashes(inv)
        result = []
        inv = inv['snapshot']
        return result if inv.nil? || inv['rootSnapshotList'].blank?

        # Handle rootSnapshotList being an Array of Hashes or a single Hash
        inv['rootSnapshotList'].to_miq_a.each do |snapshot|
          result += snapshot_inv_to_snapshot_hashes(snapshot, inv['currentSnapshot'])
        end
        result
      end

      def self.snapshot_inv_to_snapshot_hashes(inv, current, parent_uid = nil)
        result = []

        create_time_ems = inv['createTime']
        create_time = Time.parse(create_time_ems).getutc

        # Fix case where blank description comes back as a Hash instead
        description = inv['description']
        description = nil if description.kind_of?(Hash)

        nh = {
          :ems_ref     => inv['snapshot'],
          :ems_ref_obj => inv['snapshot'],
          :uid_ems     => create_time_ems,
          :uid         => create_time.iso8601(6),
          :parent_uid  => parent_uid,
          :name        => inv['name'],
          :description => description,
          :create_time => create_time,
          :current     => inv['snapshot'] == current,
        }

        result << nh

        inv['childSnapshotList'].to_miq_a.each do |child_snapshot_info|
          result += snapshot_inv_to_snapshot_hashes(child_snapshot_info, current, nh[:uid])
        end

        result
      end

      def self.inv_to_ems_folder_hashes(inv)
        result = []
        result_uids = {}

        folder_inv_to_hashes(inv[:folder], result, result_uids)
        datacenter_inv_to_hashes(inv[:dc], result, result_uids)
        storage_pod_inv_to_hashes(inv[:storage_pod], result, result_uids)

        return result, result_uids
      end

      def self.folder_inv_to_hashes(inv, result, result_uids)
        return result, result_uids if inv.nil?

        inv.each do |mor, data|
          mor = data['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          child_mors = get_mors(data, 'childEntity')

          new_result = {
            :type        => EmsFolder.name,
            :ems_ref     => mor,
            :ems_ref_obj => mor,
            :uid_ems     => mor,
            :name        => data["name"],
            :child_uids  => child_mors,
            :hidden      => false
          }
          result << new_result
          result_uids[mor] = new_result
        end
        return result, result_uids
      end

      def self.datacenter_inv_to_hashes(inv, result, result_uids)
        return result, result_uids if inv.nil?

        inv.each do |mor, data|
          mor = data['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          child_mors = get_mors(data, 'hostFolder') + get_mors(data, 'vmFolder') + get_mors(data, 'datastoreFolder')

          new_result = {
            :type        => Datacenter.name,
            :ems_ref     => mor,
            :ems_ref_obj => mor,
            :uid_ems     => mor,
            :name        => data["name"],
            :child_uids  => child_mors,
            :hidden      => false
          }
          result << new_result
          result_uids[mor] = new_result
        end
        return result, result_uids
      end

      def self.storage_pod_inv_to_hashes(inv, result, result_uids)
        return result, result_uids if inv.nil?

        inv.each do |mor, data|
          mor = data['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          child_mors = get_mors(data, 'childEntity')
          name       = data.fetch_path('summary', 'name')

          new_result = {
            :type        => StorageCluster.name,
            :ems_ref     => mor,
            :ems_ref_obj => mor,
            :uid_ems     => mor,
            :name        => name,
            :child_uids  => child_mors,
            :hidden      => false
          }

          result << new_result
          result_uids[mor] = new_result
        end
        return result, result_uids
      end

      def self.cluster_inv_to_hashes(inv)
        result = []
        result_uids = {}
        return result, result_uids if inv.nil?

        inv.each do |mor, data|
          mor = data['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          config = data["configuration"]
          das_config = config["dasConfig"]
          drs_config = config["drsConfig"]

          effective_cpu = data.fetch_path("summary", "effectiveCpu")
          effective_cpu = effective_cpu.blank? ? nil : effective_cpu.to_i
          effective_memory = data.fetch_path("summary", "effectiveMemory")
          effective_memory = effective_memory.blank? ? nil : effective_memory.to_i.megabytes

          new_result = {
            :ems_ref                 => mor,
            :ems_ref_obj             => mor,
            :uid_ems                 => mor,
            :name                    => data["name"],
            :effective_cpu           => effective_cpu,
            :effective_memory        => effective_memory,

            :ha_enabled              => das_config["enabled"].to_s.downcase == "true",
            :ha_admit_control        => das_config["admissionControlEnabled"].to_s.downcase == "true",
            :ha_max_failures         => das_config["failoverLevel"],

            :drs_enabled             => drs_config["enabled"].to_s.downcase == "true",
            :drs_automation_level    => drs_config["defaultVmBehavior"],
            :drs_migration_threshold => drs_config["vmotionRate"],

            :child_uids              => get_mors(data, 'resourcePool')
          }
          result << new_result
          result_uids[mor] = new_result
        end
        return result, result_uids
      end

      def self.rp_inv_to_hashes(inv)
        result = []
        result_uids = {}
        return result, result_uids if inv.nil?

        inv.each do |mor, data|
          mor = data['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          config = data.fetch_path("summary", "config")
          memory = config["memoryAllocation"]
          cpu = config["cpuAllocation"]

          # :is_default will be set later as we don't know until we find out who the parent is.

          new_result = {
            :ems_ref               => mor,
            :ems_ref_obj           => mor,
            :uid_ems               => mor,
            :name                  => URI.decode(data["name"].to_s),
            :vapp                  => mor.vimType == "VirtualApp",

            :memory_reserve        => memory["reservation"],
            :memory_reserve_expand => memory["expandableReservation"].to_s.downcase == "true",
            :memory_limit          => memory["limit"],
            :memory_shares         => memory.fetch_path("shares", "shares"),
            :memory_shares_level   => memory.fetch_path("shares", "level"),

            :cpu_reserve           => cpu["reservation"],
            :cpu_reserve_expand    => cpu["expandableReservation"].to_s.downcase == "true",
            :cpu_limit             => cpu["limit"],
            :cpu_shares            => cpu.fetch_path("shares", "shares"),
            :cpu_shares_level      => cpu.fetch_path("shares", "level"),

            :child_uids            => get_mors(data, 'resourcePool') + get_mors(data, 'vm')
          }
          result << new_result
          result_uids[mor] = new_result
        end
        return result, result_uids
      end

      def self.customization_spec_inv_to_hashes(inv)
        result = []
        return result if inv.nil?

        inv.each do |spec_inv|
          result << {
            :name             => spec_inv["name"].to_s,
            :typ              => spec_inv["type"].to_s,
            :description      => spec_inv["description"].to_s,
            :last_update_time => spec_inv["lastUpdateTime"].to_s,
            :spec             => spec_inv["spec"]
          }
        end
        result
      end

      def self.link_ems_metadata(data, inv)
        inv_to_data_types = {:folder => :folders, :dc => :folders, :storage_pod => :folders,
                             :cluster => :clusters, :rp => :resource_pools,
                             :storage => :storages, :host => :hosts, :vm => :vms}

        [:folders, :clusters, :resource_pools, :hosts].each do |parent_type|
          data[parent_type].each do |parent_data|
            child_uids = parent_data.delete(:child_uids)
            next if child_uids.blank?

            ems_children = parent_data[:ems_children] = {}

            child_uids.each do |child_uid|
              # Find this child in the inventory data.  If we have a host_res,
              #   check its children instead.
              child_type, child_inv = inv_target_by_mor(child_uid, inv)
              if child_type == :host_res
                child_uid = get_mors(child_inv, 'host')[0]
                if child_uid.nil?
                  child_type = child_inv = nil
                else
                  child_type, child_inv = inv_target_by_mor(child_uid, inv)
                end
              end
              next if child_inv.nil?

              child_type = inv_to_data_types[child_type]

              child = data.fetch_path(:uid_lookup, child_type, child_uid)
              unless child.nil?
                ems_children[child_type] ||= []
                ems_children[child_type] << child
              end
            end
          end
        end
      end

      def self.link_root_folder(data)
        # Find the folder that does not have a parent folder

        # Since the root folder is almost always called "Datacenters", move that
        #   folder to the head of the list as an optimization
        dcs, folders = data[:folders].partition { |f| f[:name] == "Datacenters" }
        dcs.each { |dc| folders.unshift(dc) }
        data[:folders] = folders

        found = data[:folders].find do |child|
          !data[:folders].any? do |parent|
            children = parent.fetch_path(:ems_children, :folders)
            children && children.any? { |c| c.object_id == child.object_id }
          end
        end

        unless found.nil?
          data[:ems_root] = found
        else
          _log.warn "Unable to find a root folder."
        end
      end

      def self.set_hidden_folders(data)
        return if data[:ems_root].nil?

        # Mark the root folder as hidden
        data[:ems_root][:hidden] = true

        # Mark all child folders of each Datacenter as hidden
        # e.g.: "vm", "host", "datastore"
        data[:folders].select { |f| f[:type] == "Datacenter" }.each do |dc|
          dc_children = dc.fetch_path(:ems_children, :folders)
          dc_children.to_miq_a.each do |f|
            f[:hidden] = true
          end
        end
      end

      def self.set_default_rps(data)
        # Update the default RPs and their names to reflect their parent relationships
        parent_classes = {:clusters => 'EmsCluster', :hosts => 'Host'}

        [:clusters, :hosts].each do |parent_type|
          data[parent_type].each do |parent|
            rps = parent.fetch_path(:ems_children, :resource_pools)
            next if rps.blank?

            rps.each do |rp|
              rp[:is_default] = true
              rp[:name] = "Default for #{Dictionary.gettext(parent_classes[parent_type], :type => :model, :notfound => :titleize)} #{parent[:name]}"
            end
          end
        end

        data[:resource_pools].each { |rp| rp[:is_default] = false unless rp[:is_default] }
      end

      #
      # Helper methods for EMS inventory parsing methods
      #

      def self.normalize_storage_uid(inv)
        ############################################################################
        # For VMFS, we will use the GUID as the identifier
        ############################################################################

        # VMFS has the GUID in the url:
        #   From VC4:  sanfs://vmfs_uuid:49861d7d-25f008ac-ffbf-001b212bed24/
        #   From VC5:  ds:///vmfs/volumes/49861d7d-25f008ac-ffbf-001b212bed24/
        #   From ESX4: /vmfs/volumes/49861d7d-25f008ac-ffbf-001b212bed24
        url = inv.fetch_path('summary', 'url').to_s.downcase
        return $1 if url =~ /([0-9a-f]{8}-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{12})/

        ############################################################################
        # For NFS on VC5, we will use the "half GUID" as the identifier
        # For other NFS, we will use a path as the identifier in the form: ipaddress/path/parts
        ############################################################################

        # NFS on VC5 has the "half GUID" in the url:
        #   ds:///vmfs/volumes/18f2f698-aae589d5/
        return $1 if url[0, 5] == "ds://" && url =~ /([0-9a-f]{8}-[0-9a-f]{8})/

        # NFS on VC has a path in the url:
        #   netfs://192.168.254.80//shares/public/
        return url[8..-1].gsub('//', '/').chomp('/') if url[0, 8] == "netfs://"

        # NFS on ESX has the path in the datastore instead:
        #   192.168.254.80:/shares/public
        datastore = inv.fetch_path('summary', 'datastore').to_s.downcase
        return datastore.gsub(':/', '/') if datastore =~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/

        # For anything else, we return the url
        url
      end

      def self.normalize_vm_storage_uid(inv, full_storage_inv)
        ############################################################################
        # For VMFS, we will use the GUID as the identifier
        ############################################################################

        # VMFS has the GUID in the vmLocalPathName:
        #   From VC4:  sanfs://vmfs_uuid:49861d7d-25f008ac-ffbf-001b212bed24/RedHat6.2/RedHat6.2.vmx
        #   From VC5:  ds://vmfs/volumes/49861d7d-25f008ac-ffbf-001b212bed24/RedHat6.2/RedHat6.2.vmx
        #   From ESX5: /vmfs/volumes/49861d7d-25f008ac-ffbf-001b212bed24/RedHat6.2/RedHat6.2.vmx
        local_path_name = inv.fetch_path('summary', 'config', 'vmLocalPathName').to_s.downcase
        return $1 if local_path_name =~ /([0-9a-f]{8}-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{12})/

        ############################################################################
        # For NFS on VC5, we will use the "half GUID" as the identifier
        # For other NFS, we will use a path as the identifier in the form: ipaddress/path/parts
        ############################################################################

        # NFS on VC5 has the "half GUID" in the vmLocalPathName:
        #   ds:///vmfs/volumes/18f2f698-aae589d5/RedHat6.2/RedHat6.2.vmx
        return $1 if local_path_name[0, 5] == "ds://" && local_path_name =~ /([0-9a-f]{8}-[0-9a-f]{8})/

        # NFS on VC has a full netfs:// path in the vmLocalPathName:
        #   netfs://192.168.254.80//shares/public/RedHat6.2/RedHat6.2.vmx
        # and the "[storage] path" in the vmPathName:
        #   [NFSUbuntu] RedHat6.2/RedHat6.2.vmx
        #
        # Get the sub-path from the vmPathName, chomp it off the vmLocalPathName,
        #   and clean the result to the format.
        path_name = inv.fetch_path('summary', 'config', 'vmPathName').to_s.downcase
        path = $1.strip if path_name =~ /^\[[^\]]*\]\s*(.*)$/
        local_path = local_path_name.chomp(path).chomp('/')
        return local_path[8..-1].gsub('//', '/') if local_path_name[0..7] == "netfs://"

        # NFS on ESX has a local path with a half-GUID in the vmLocalPathName:
        #   /vmfs/volumes/d8d30672-9fe697d9/RedHat6.2/RedHat6.2.vmx
        # and the "[storage] path" in the vmPathName:
        #   [NFSUbuntu] RedHat6.2/RedHat6.2.vmx
        #
        # The storage inventory has a half-GUID in the url:
        #   /vmfs/volumes/d8d30672-9fe697d9
        # and a path in the datastore:
        #   192.168.254.80:/shares/public
        #
        # Get the sub-path from the vmPathName, chomp it off the vmLocalPathName,
        #   use the leftover half-GUID to find the storage in the full storage
        #   inventory by url, and then clean the datastore from that storage.
        s_data = full_storage_inv.values.find { |v| v.fetch_path('summary', 'url') == local_path }
        datastore = s_data.fetch_path('summary', 'datastore').to_s.downcase unless s_data.nil?
        return datastore.gsub(':/', '/') if datastore =~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/

        # For anything else, we return the local path name
        local_path_name
      end

      def self.get_mor_type(mor)
        mor =~ /^([^-]+)-/ ? $1 : nil
      end

      def self.get_mors(inv, key)
        # Take care of case where a single or no element is a String
        return [] unless inv.kind_of?(Hash)
        d = inv[key]
        d = d['ManagedObjectReference'] if d.kind_of?(Hash)
        d.to_miq_a
      end

      VC_MOR_FILTERS = [
        [:host_res,    'domain'],
        [:cluster,     'domain'],
        [:dc,          'datacenter'],
        [:folder,      'group'],
        [:rp,          'resgroup'],
        [:storage,     'datastore'],
        [:storage_pod, 'group'],
        [:host,        'host'],
        [:vm,          'vm']
      ]

      def self.inv_target_by_mor(mor, inv)
        target_type = target = nil
        mor_type = get_mor_type(mor)

        VC_MOR_FILTERS.each do |type, mor_filter|
          next unless mor_type.nil? || mor_type == mor_filter
          target = inv[target_type = type][mor]
          break unless target.nil?
        end

        target_type = nil if target.nil?
        return target_type, target
      end

      def self.host_parent_resource(host_mor, inv)
        # Find the parent in the host_res or the cluster by host's mor
        parent = parent_type = nil
        [:host_res, :cluster].each do |type|
          parent_data = inv[parent_type = type]
          next if parent_data.nil?
          parent = parent_data.find { |_mor, parent_inv| get_mors(parent_inv, 'host').include?(host_mor) }
          break unless parent.nil?
        end

        unless parent.nil?
          parent_mor, parent = *parent
        else
          parent_type = parent_mor = nil
        end
        return parent_type, parent_mor, parent
      end

      #
      # Datastore File Inventory Parsing
      #

      def self.datastore_file_inv_to_hashes(inv, vm_ids_by_path)
        return [] if inv.nil?

        result = inv.collect do |data|
          name = data['fullPath']
          is_dir = data['fileType'] == 'FileFolderInfo'
          vm_id = vm_ids_by_path[is_dir ? name : File.dirname(name)]

          new_result = {
            :name      => name,
            :size      => data['fileSize'],
            :base_name => data['path'],
            :ext_name  => File.extname(data['path'])[1..-1].to_s.downcase,
            :mtime     => data['modification'],
            :rsc_type  => is_dir ? 'dir' : 'file'
          }
          new_result[:vm_or_template_id] = vm_id unless vm_id.nil?

          new_result
        end

        result
      end

      #
      # Other
      #

      def self.host_inv_to_firewall_rules_hashes(inv)
        inv = inv.fetch_path('config', 'firewall', 'ruleset')

        result = []
        return result if inv.nil?

        inv.to_miq_a.each do |data|
          # Collect Rule Set values
          current_rule_set = {:group => data['key'], :enabled => data['enabled'], :required => data['required']}

          # Process each Firewall Rule
          data['rule'].each do |rule|
            rule_string = rule['endPort'].nil? ? "#{rule['port']}" : "#{rule['port']}-#{rule['endPort']}"
            rule_string << " (#{rule['protocol']}-#{rule['direction']})"
            result << {
              :name          => "#{data['key']} #{rule_string}",
              :display_name  => "#{data['label']} #{rule_string}",
              :host_protocol => rule['protocol'],
              :direction     => rule['direction'].chomp('bound'),  # Turn inbound/outbound to just in/out
              :port          => rule['port'],
              :end_port      => rule['endPort'],
            }.merge(current_rule_set)
          end
        end
        result
      end

      def self.host_inv_to_advanced_settings_hashes(inv)
        inv = inv['config']

        result = []
        return result if inv.nil?

        settings = inv['option'].to_miq_a.index_by { |o| o['key'] }
        details = inv['optionDef'].to_miq_a.index_by { |o| o['key'] }

        settings.each do |key, setting|
          detail = details[key]

          # TODO: change the 255 length 'String' columns, truncated below, to text
          # A vmware string type was confirmed to allow up to 9932 bytes
          result << {
            :name          => key,
            :value         => setting['value'].to_s,
            :display_name  => detail.nil? ? nil : truncate_value(detail['label']),
            :description   => detail.nil? ? nil : truncate_value(detail['summary']),
            :default_value => detail.nil? ? nil : truncate_value(detail.fetch_path('optionType', 'defaultValue')),
            :min           => detail.nil? ? nil : truncate_value(detail.fetch_path('optionType', 'min')),
            :max           => detail.nil? ? nil : truncate_value(detail.fetch_path('optionType', 'max')),
            :read_only     => detail.nil? ? nil : detail.fetch_path('optionType', 'valueIsReadonly')
          }
        end
        result
      end

      def self.truncate_value(val)
        return val[0, 255] if val.kind_of?(String)
      end

      #
      # Inventory parsing for Reconfigure VM Task event
      #

      def self.reconfig_inv_to_hashes(inv)
        uids = {}
        result = {:uid_lookup => uids}

        uids[:storages] = reconfig_storage_inv_to_hashes(inv[:storage])
        uids[:lans] = reconfig_host_inv_to_lan_hashes(inv[:host])
        result[:vms] = reconfig_vm_inv_to_hashes(inv[:vm], uids[:storages], uids[:lans])

        result
      end

      def self.reconfig_storage_inv_to_hashes(inv)
        result_uids = {}
        return result_uids if inv.nil?

        inv.each do |mor, storage_inv|
          mor = storage_inv['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          summary = storage_inv["summary"]
          next if summary.nil?

          loc = normalize_storage_uid(storage_inv)

          new_result = {
            :ems_ref     => mor,
            :ems_ref_obj => mor,
            :name        => summary["name"],
            :location    => loc,
          }

          result_uids[mor] = new_result
        end
        result_uids
      end

      def self.reconfig_host_inv_to_lan_hashes(inv)
        result_uids = {}

        inv.each do |_mor, host_inv|
          host_inv = host_inv.fetch_path('config', 'network')
          return result_uids if host_inv.nil?

          host_inv['portgroup'].to_miq_a.each do |data|
            spec = data['spec']
            next if spec.nil?

            uid = spec['name']

            new_result = {
              :uid_ems => uid,
            }
            result_uids[uid] = new_result
          end
        end
        result_uids
      end

      def self.reconfig_vm_inv_to_hashes(inv, storage_uids, lan_uids)
        result = []
        return result if inv.nil?

        inv.each do |mor, vm_inv|
          mor = vm_inv['MOR'] # Use the MOR directly from the data since the mor as a key may be corrupt

          summary = vm_inv["summary"]
          summary_config = summary["config"] unless summary.nil?
          pathname = summary_config["vmPathName"] unless summary_config.nil?

          config = vm_inv["config"]

          # Determine if the data from VC is valid.
          invalid, err = if summary_config.nil? || config.nil?
                           type = ['summary_config', 'config'].find_all { |t| eval(t).nil? }.join(", ")
                           [true, "Missing configuration for VM [#{mor}]: #{type}."]
                         elsif summary_config["uuid"].blank?
                           [true, "Missing UUID for VM [#{mor}]."]
                         elsif pathname.blank?
                           _log.debug "vmPathname class: [#{pathname.class}] inspect: [#{pathname.inspect}]"
                           [true, "Missing pathname location for VM [#{mor}]."]
                         else
                           false
                         end

          if invalid
            _log.warn "#{err} Skipping."

            result << {
              :invalid     => true,
              :ems_ref     => mor,
              :ems_ref_obj => mor
            }
            next
          end

          affinity_set = config.fetch_path('cpuAffinity', 'affinitySet')
          # The affinity_set will be an array of integers if set
          cpu_affinity = nil
          cpu_affinity = affinity_set.kind_of?(Array) ? affinity_set.join(",") : affinity_set.to_s if affinity_set

          tools_status = summary.fetch_path('guest', 'toolsStatus')
          tools_status = nil if tools_status.blank?

          standby_act = nil
          power_options = config["defaultPowerOps"]
          unless power_options.blank?
            standby_act = power_options["standbyAction"] if power_options["standbyAction"]
          end

          # Collect the reservation information
          resource_config = vm_inv["resourceConfig"]
          memory = resource_config && resource_config["memoryAllocation"]
          cpu    = resource_config && resource_config["cpuAllocation"]

          hardware = vm_inv_to_hardware_hash(vm_inv)
          hardware[:disks] = vm_inv_to_disk_hashes(vm_inv, storage_uids)
          hardware[:guest_devices], = vm_inv_to_guest_device_hashes(vm_inv, lan_uids)
          uid = hardware[:bios]

          result << {
            :ems_ref               => mor,
            :ems_ref_obj           => mor,
            :uid_ems               => uid,
            :name                  => URI.decode(summary_config["name"]),
            :tools_status          => tools_status,
            :standby_action        => standby_act,
            :cpu_affinity          => cpu_affinity,

            :memory_reserve        => memory && memory["reservation"],
            :memory_reserve_expand => memory && memory["expandableReservation"].to_s.downcase == "true",
            :memory_limit          => memory && memory["limit"],
            :memory_shares         => memory && memory.fetch_path("shares", "shares"),
            :memory_shares_level   => memory && memory.fetch_path("shares", "level"),

            :cpu_reserve           => cpu && cpu["reservation"],
            :cpu_reserve_expand    => cpu && cpu["expandableReservation"].to_s.downcase == "true",
            :cpu_limit             => cpu && cpu["limit"],
            :cpu_shares            => cpu && cpu.fetch_path("shares", "shares"),
            :cpu_shares_level      => cpu && cpu.fetch_path("shares", "level"),

            :operating_system      => vm_inv_to_os_hash(vm_inv),
            :hardware              => hardware,
          }
        end
        result
      end
    end
  end
end
