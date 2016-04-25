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
    log_header = "Collecting data for EMS HERE!!!: [#{@ems.name}] id: [#{@ems.id}]"

    _log.info("#{log_header}...")
    get_cloud_networks
    get_network_ports
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
    networks = @network.networks.all.select {|n| n.datacenter.name == @ems.provider_region}
    process_collection(networks, :cloud_networks) { |cloud_network| parse_cloud_network(cloud_network) }
  end

  def get_cloud_subnets(cloud_network)
    subnets = cloud_network.subnets
    process_collection(subnets, :cloud_subnets) { |subnet| parse_cloud_subnet(subnet) }
  end

  def get_network_ports

  end

  def parse_cloud_network(cloud_network)
    uid = cloud_network.id

    type_suffix = "::#{cloud_network.network_space.capitalize}"

    cloud_subnets = get_cloud_subnets(cloud_network).collect do |raw_subnet|
      @data_index.fetch_path(:cloud_subnets, raw_subnet.id)
    end

    new_result = {
      :type          => self.class.cloud_network_type + type_suffix,
      :ems_ref       => cloud_network.id,
      :name          => cloud_network.name,
      :status        => "active",
      :cidr          => nil,
      :enabled       => true,
      :cloud_subnets => cloud_subnets,
    }
    return uid, new_result
  end

  def parse_cloud_subnet(subnet)
    uid = subnet.id

    new_result = {
      :type              => self.class.cloud_subnet_type,
      :ems_ref           => uid,
      :name              => subnet.name,
      :cidr              => "#{subnet.network_id}/#{subnet.cidr}",
      :ip_version        => subnet.ip_version,
      :network_protocol  => "ipv#{subnet.ip_version}",
      :gateway           => subnet.gateway_ip,
      :availability_zone => @data_index.fetch_path(:availability_zones, 'default'),
    }
    return uid, new_result
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
