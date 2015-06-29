require 'MiqScvmmVm'

class MiqScvmmHost
  def initialize(invObj, vmh)
    unless invObj.nil?
      @invObj                 = invObj
      @vmService              = invObj.vmService
      @sic                    = invObj.sic
    end

    init(vmh)
	end # def initialize

	def init(vmh)
    #@vmService.stdout.puts "Init Hash for ScvmmVm [#{vmh.inspect}]"

    if vmh.empty?
      @props = {}
      return
    end

    @vmh                    = vmh
    @props                  = vmh[:Props]
    @name                   = @props[:Name]
    @uuid                   = @props[:ID]

    @datacenterName         = nil
  end

	def powerState
    case @props[:StatusString].to_s.downcase
    when "running" then "on"
    when "paused"  then "suspended"
    when "saved"  then "suspended"
    when "saved state"  then "suspended"
    when "stopped", "PowerOff" then "off"
    else "unknown"
    end
	end

	def poweredOn?
    powerState == "on"
	end

	def poweredOff?
    powerState == "off"
	end

  def storages
    result = []
    disks =@props[:DiskVolumes].to_miq_a
    disks.each do |d|
      props = d[:Props]
      next if props[:Name].include?('\\\\?\\')
      name = File.path_to_uri(props[:Name], props[:VMHost])
      result << {
        :uid_ems=> props[:ID].downcase,
        :store_type=> "NAS",
        :name=> name,
        :free_space=> props[:FreeSpace],
        :total_space=> props[:Capacity],
        :location=> name,
        :multiplehostaccess=> props[:IsSANMigrationPossible]
      }
    end
    return result
  end

  def to_inv_h()
      props = @props

      name = props[:Name]
      hostname = props[:FullyQualifiedDomainName]

      vendor = 'microsoft'
      os = {}
      hardware = {}
      storage_uids = []
      product_name = props[:VirtualizationPlatform][:ToString]
      power_state = props[:ComputerState][:ToString].to_s.downcase == 'responding' ? 'on' : 'off'

      os_props = props[:OperatingSystem][:Props]
      version = os_props[:Version]
      version = version.nil? ? [0,0,0] : version.split('.')
      vm_host_group_uid = props[:VMHostGroup][:Props][:ID] rescue nil

      os[:name] = name
      os[:product_name] = os_props[:Name].strip.chomp(',').strip
      os[:version] = "#{version[0]}.#{version[1]}"
      os[:build_number] = version[2]
      os[:product_type] = 'ServerNT'
      os[:bitness] = os_props[:Architecture] == 'amd64' ? '64' : '32'

      hardware[:guest_os] = props[:VirtualizationPlatformString]
      hardware[:guest_os_full_name] = props[:VirtualizationPlatformString]
      hardware[:cpu_speed] = props[:ProcessorSpeed]
      hardware[:cpu_type] = props[:CPUManufacturer]
      hardware[:manufacturer] = props[:CPUManufacturer]
      hardware[:model] = props[:VirtualizationPlatformDetail]
      #hardware[:number_of_nics] = nil
      hardware[:memory_cpu] = (props[:TotalMemory].to_f/1048576).round

      hardware[:numvcpus] = props[:PhysicalCPUCount]
      hardware[:cores_per_socket] = props[:CoresPerCPU]
      hardware[:logical_cpus] = hardware[:cores_per_socket].to_i * hardware[:numvcpus].to_i

      #Guest OS summary_config['product'] = {'name' => props[:VirtualizationPlatformString]}

      # Get the IP address
      begin
        # IPSocket.getaddress(hostname) is not used because it was appending a ".com"
        #   to the "esxdev001.localdomain" which resolved to a real internet address.
        #   Socket.getaddrinfo does the right thing
        # TODO create a utility method to get the address information using Socket.getaddrinfo

        # The IP is the 4th item in the nested array returned by getaddrinfo
        ipaddress = Socket.getaddrinfo(hostname, nil)[0][3]
        #$log.debug "MIQ(Host-save_ems_inventory) EMS: [#{ems.name}] IP lookup by hostname: [#{hostname}] completed...returned IP: [#{ipaddress}]"
      rescue => err
        # If the Socket.getaddrinfo raises an error, attempt to find the IP address in the SCVMM data, otherwise, use the hostname of the machine
        #$log.warn "MIQ(Host-save_ems_inventory) EMS: [#{ems.name}] IP lookup by hostname: [#{hostname}] failed: [#{err}]"
        #          ipaddress = Host.find_esx_ip_from_vim_inv(config_network)
        ipaddress = hostname if ipaddress.nil?
        #$log.debug "MIQ(Host-save_ems_inventory) EMS: [#{ems.name}] IP lookup by hostname: [#{hostname}] using IP: [#{ipaddress}]"
      end

      result = {
        :uid_ems => props[:ID].downcase,
        
        :name => name,
        :hostname => hostname,
        :ipaddress => ipaddress,
        :vmm_vendor => vendor,
        :vmm_version => os["version"],
        :vmm_product => product_name,
        :vmm_buildnumber => os["build"],
        :power_state => power_state,
        :uid_folder => vm_host_group_uid,

        :operating_system => os,
        :hardware => hardware,

#        :config_network_inv => nil,
        :storages => self.storages,
        :vms => []
      }

    return result
  end
end
