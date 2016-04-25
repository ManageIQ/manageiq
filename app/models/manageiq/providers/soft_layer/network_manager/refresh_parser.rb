class ManageIQ::Providers::SoftLayer::NetworkManager::RefreshParser
  include ManageIQ::Providers::SoftLayer::RefreshHelperMethods
  include Vmdb::Logging

  def self.ems_inv_to_hashes(ems, options = nil)
    new(ems, options).ems_inv_to_hashes
  end

  def initialize(ems, options = nil)
    options ||= {}
    @ems               = ems
    @compute           = ems.connect
    @network           = ems.connect(options.merge(:service => "network"))
    @dns               = ems.connect(options.merge(:service => "dns"))
    @options           = options
    @data              = {}
    @data_index        = {}
  end

  def ems_inv_to_hashes
    log_header = "Collecting data for EMS: [#{@ems.name}] id: [#{@ems.id}]"

    _log.info("#{log_header}...")
    get_cloud_networks
    get_network_ports
    get_network_routers
    _log.info("#{log_header}...Complete")

    @data
  end

  private

  def parent_manager_fetch_path(collection, ems_ref)
    @parent_manager_data ||= {}
    return @parent_manager_data.fetch_path(collection, ems_ref) if @parent_manager_data.has_key_path?(collection,
                                                                                                      ems_ref)

    @parent_manager_data.store_path(collection,
                                    ems_ref,
                                    @ems.public_send(collection).try(:where, :ems_ref => ems_ref).try(:first))
  end

  def get_cloud_networks
    networks = @network.networks.all.select { |n| n.datacenter.name == @ems.provider_region }
    process_collection(networks, :cloud_networks) { |cloud_network| parse_cloud_network(cloud_network) }
  end

  def get_cloud_subnets(cloud_network)
    subnets = cloud_network.subnets
    process_collection(subnets, :cloud_subnets) { |subnet| parse_cloud_subnet(subnet) }
  end

  def get_network_ports
    instances = @compute.servers.all.select { |s| s.datacenter == @ems.provider_region }

    instances.each do |instance|
      ports = instance.network_components
      process_collection(ports, :network_ports) { |port| parse_network_port(instance.id, port) }
    end
  end

  def get_network_routers
    networks = @data.fetch_path(:cloud_networks)
    networks.each do |network|
      uid, new_result = parse_network_router(network[:network_router])

      @data[:network_routers] ||= []
      @data[:network_routers] << new_result
      router = @data_index.store_path(:network_routers, uid, new_result)

      network[:cloud_subnets].each { |subnet| subnet[:network_router] = router }
      network.delete(:network_router)
    end
  end

  def parse_cloud_network(cloud_network)
    uid = cloud_network.id.to_s

    type_suffix = "::#{cloud_network.network_space.capitalize}"

    cloud_subnets = get_cloud_subnets(cloud_network).collect do |raw_subnet|
      @data_index.fetch_path(:cloud_subnets, raw_subnet.id.to_s)
    end

    new_result = {
      :type           => self.class.cloud_network_type + type_suffix,
      :ems_ref        => uid,
      :name           => cloud_network_name(cloud_network),
      :status         => "active",
      :cidr           => nil,
      :enabled        => true,
      :cloud_subnets  => cloud_subnets,
      :network_router => cloud_network.router
    }
    return uid, new_result
  end

  def parse_cloud_subnet(subnet)
    uid = subnet.id.to_s

    cidr = "#{subnet.network_id}/#{subnet.cidr}"
    name = subnet.name.blank? ? cidr : subnet.name

    new_result = {
      :type              => self.class.cloud_subnet_type,
      :ems_ref           => uid,
      :name              => name,
      :cidr              => cidr,
      :ip_version        => subnet.ip_version,
      :network_protocol  => "ipv#{subnet.ip_version}",
      :gateway           => subnet.gateway_ip,
      :availability_zone => @data_index.fetch_path(:availability_zones, 'default'),
    }
    return uid, new_result
  end

  def parse_network_port(device_ref, network_port)
    uid = network_port.id.to_s
    name = network_port.name.blank? ? network_port.mac_address : "#{network_port.name}#{network_port.port}"
    subnet_id = @network.ips.by_address(network_port.primary_ip_address).subnet_id.to_s

    new_result = {
      :type                       => self.class.network_port_type,
      :name                       => name,
      :ems_ref                    => uid,
      :status                     => network_port.status.downcase,
      :mac_address                => network_port.mac_address,
      :device_ref                 => device_ref,
      :device                     => parent_manager_fetch_path(:vms, device_ref),
      :fixed_ips                  => network_port.primary_ip_address,
      :cloud_subnet_network_ports => [{
        :address      => network_port.primary_ip_address,
        :cloud_subnet => @data_index.fetch_path(:cloud_subnets, subnet_id)
      }]
    }
    return uid, new_result
  end

  def parse_network_router(network_router)
    uid = network_router["id"].to_s
    new_result = {
      :type    => self.class.network_router_type,
      :name    => network_router["hostname"],
      :ems_ref => uid
    }
    return uid, new_result
  end

  def cloud_network_name(cloud_network)
    return cloud_network.name if cloud_network.name.present?

    "#{cloud_network.network_space.capitalize} VLAN on #{cloud_network.router['hostname']}"
  end

  class << self
    def cloud_network_type
      ManageIQ::Providers::SoftLayer::NetworkManager::CloudNetwork.name
    end

    def cloud_subnet_type
      ManageIQ::Providers::SoftLayer::NetworkManager::CloudSubnet.name
    end

    def network_port_type
      ManageIQ::Providers::SoftLayer::NetworkManager::NetworkPort.name
    end

    def network_router_type
      ManageIQ::Providers::SoftLayer::NetworkManager::NetworkRouter.name
    end
  end
end
