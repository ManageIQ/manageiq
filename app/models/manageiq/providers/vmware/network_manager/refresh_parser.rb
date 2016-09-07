module ManageIQ::Providers
  class Vmware::NetworkManager::RefreshParser
    include ManageIQ::Providers::Vmware::RefreshHelperMethods
    VappNetwork = Struct.new(:id, :name, :type, :is_shared, :gateway, :dns1, :dns2)

    def initialize(ems, options = nil)
      @ems        = ems
      @connection = ems.connect
      @options    = options || {}
      @data       = {}
      @data_index = {}
      @inv        = Hash.new { |h, k| h[k] = [] }
      @org        = @connection.organizations.first
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $log.info("#{log_header}...")

      get_networks
      get_network_ports

      $log.info("#{log_header}...Complete")

      @data
    end

    private

    def get_networks
      # fetch org VDC networks
      @inv[:networks] = @org.networks

      # fetch vApp networks
      @inv[:networks] += get_vapp_networks

      process_collection(@inv[:networks], :cloud_networks) { |n| parse_network(n) }
      process_collection(@inv[:networks], :cloud_subnets) { |n| parse_network_subnet(n) }
    end

    def get_network_ports
      # TODO: Update FOG so that it will provide list of network ports. Currently, it is only possible to obtain
      # very little data, barely enough to tell to which network the VM is connected to.
      @inv[:vm_networks] = []
      @org.vdcs.each do |vdc|
        vdc.vapps.each do |vapp|
          vapp.vms.each do |vm|
            @inv[:vm_networks] += vm.network_adapters.each_with_index.map do |net_if, i|
              net_if[:vapp] = vapp
              net_if[:vm] = vm
              net_if[:vm_network] = vm.network
              net_if[:idx] = i
              net_if
            end
          end
        end
      end

      process_collection(@inv[:vm_networks], :network_ports) { |n| parse_network_port(n) }
    end

    # Parsing

    def parse_network(network)
      uid = network.id
      network_type = network.type.include?("vcloud.orgNetwork") ?
          self.class.cloud_network_vdc_type : self.class.cloud_network_vapp_type

      new_result = {
        :name          => network.name,
        :ems_ref       => uid,
        :enabled       => true,
        :shared        => network.is_shared,
        :type          => network_type,
        :cloud_subnets => []
      }
      return uid, new_result
    end

    def parse_network_subnet(network)
      uid = subnet_id(network)
      new_result = {
        :name            => subnet_name(network),
        :ems_ref         => uid,
        :gateway         => network.gateway,
        :dns_nameservers => [network.dns1, network.dns2],
        :type            => self.class.cloud_subnet_type,
        :network_ports   => [],
      }

      # assign myself to the network
      @data_index.fetch_path(:cloud_networks, network.id)[:cloud_subnets] << new_result

      return uid, new_result
    end

    def parse_network_port(net_if)
      uid = port_id(net_if)
      vm_uid = net_if[:vm].id

      new_result = {
        :type       => self.class.network_port_type,
        :name       => port_name(net_if),
        :ems_ref    => uid,
        :device_ref => vm_uid,
        :device     => @ems.vms.try(:where, :ems_ref => vm_uid).try(:first),
      }

      # find network by name, since network name is all what we are given from FOG
      # TODO: update FOG since network *name* is not unique - network *id* should be provided
      network = @data[:cloud_networks].find { |n| n[:name] == net_if[:network] }
      network ||= @data[:cloud_networks].find do |n|
        n[:name] == vapp_network_name(net_if[:network], net_if[:vapp])
      end

      unless network.nil?
        subnet = network[:cloud_subnets].first
        cloud_subnet_network_port = {
          :address      => net_if["ip_address"],
          :cloud_subnet => subnet
        }
        new_result[:cloud_subnet_network_ports] = [cloud_subnet_network_port]
      end

      return uid, new_result
    end

    # Utility

    def get_vapp_networks
      vdc_network_names = Set.new @inv[:networks].map(&:name)
      vapp_networks = []
      @org.vdcs.each do |vdc|
        vdc.vapps.each do |vapp|
          vapp.network_config.map do |net_conf|
            name = net_conf[:networkName]

            next if vdc_network_names.include? name

            vapp_networks << VappNetwork.new(
              vapp_network_id(name, vapp),
              vapp_network_name(name, vapp),
              "application/vnd.vmware.vcloud.vAppNetwork+xml"
            )
          end
        end
      end

      vapp_networks
    end

    def subnet_id(network)
      "subnet-#{network.id}"
    end

    def subnet_name(network)
      "subnet-#{network.name}"
    end

    def vapp_network_id(name, vapp)
      "#{vapp.id}_#{name}"
    end

    def vapp_network_name(name, vapp)
      "#{name} (#{vapp.name})"
    end

    def port_id(net_if)
      "#{net_if[:vm].id}#NIC##{net_if[:idx]}"
    end

    def port_name(net_if)
      "#{net_if[:vm].name}#NIC##{net_if[:idx]}"
    end

    class << self
      def cloud_network_vdc_type
        "ManageIQ::Providers::Vmware::NetworkManager::CloudNetwork::OrgVdcNet"
      end

      def cloud_network_vapp_type
        "ManageIQ::Providers::Vmware::NetworkManager::CloudNetwork::VappNet"
      end

      def cloud_subnet_type
        "ManageIQ::Providers::Vmware::NetworkManager::CloudSubnet"
      end

      def network_router_type
        "ManageIQ::Providers::Vmware::NetworkManager::NetworkRouter"
      end

      def network_port_type
        "ManageIQ::Providers::Vmware::NetworkManager::NetworkPort"
      end
    end
  end
end
