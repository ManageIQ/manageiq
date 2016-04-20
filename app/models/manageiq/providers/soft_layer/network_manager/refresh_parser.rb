class ManageIQ::Providers::SoftLayer::NetworkManager::RefreshParser
  include ManageIQ::Providers::SoftLayer::RefreshHelperMethods
  include Vmdb::Logging

  def self.ems_inv_to_hashes(ems, options = nil)
    new(ems, options).ems_inv_to_hashes
  end

  def initialize(ems, options = nil)
    @ems               = ems
    @compute           = ems.connect
    @network           = ems.connect(options.merge(:service => "network"))
    @dns               = ems.connect(options.merge(:service => "dns"))
    @options           = options
    @data              = {}
    @data_index        = {}
  end

  def ems_inv_to_hashes
    log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

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
    networks = @network.networks.all
    process_collection(networks, :cloud_networks) { |cloud_network| parse_cloud_network(cloud_network) }
  end

  def get_cloud_subnets(cloud_network)
    subnets = cloud_network.subnets
    process_collection(subnets, :cloud_subnets) { |subnet| parse_cloud_subnet(subnet) }
  end

  def parse_cloud_network(cloud_network)
    cloud_subnets = get_cloud_subnets(cloud_network).collect do |raw_subnet|
      @data_index.fetch_path(:cloud_subnets, raw_subnet.id)
    end

    uid = cloud_network.id

    new_result = {
      :ems_ref       => cloud_network.id,
      :name          => cloud_network.name,
      :cidr          => cloud_network.address_space,
      :enabled       => true,
      :cloud_subnets => cloud_subnets,
    }
    return uid, new_result
  end

  def parse_cloud_subnet(subnet)
    uid = subnet.id
    new_result = {
      :ems_ref           => uid,
      :name              => subnet.name,
      :cidr              => subnet.address_space,
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
  end
end
