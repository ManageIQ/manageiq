# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

class ManageIQ::Providers::Azure::NetworkManager::RefreshParser
  include ManageIQ::Providers::Azure::RefreshHelperMethods
  include Vmdb::Logging

  def self.ems_inv_to_hashes(ems, options = nil)
    new(ems, options).ems_inv_to_hashes
  end

  def initialize(ems, options = nil)
    @ems               = ems
    @config            = ems.connect
    @subscription_id   = @config.subscription_id
    @rgs               = ::Azure::Armrest::ResourceGroupService.new(@config)
    @vns               = ::Azure::Armrest::Network::VirtualNetworkService.new(@config)
    @ips               = ::Azure::Armrest::Network::IpAddressService.new(@config)
    @nis               = ::Azure::Armrest::Network::NetworkInterfaceService.new(@config)
    @nsg               = ::Azure::Armrest::Network::NetworkSecurityGroupService.new(@config)
    @lbs               = ::Azure::Armrest::Network::LoadBalancerService.new(@config)
    @options           = options || {}
    @data              = {}
    @data_index        = {}
    @resource_to_stack = {}
  end

  def ems_inv_to_hashes
    log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

    _log.info("#{log_header}...")
    get_security_groups
    get_cloud_networks
    get_network_ports
    get_floating_ips
    get_load_balancers
    get_load_balancer_pools
    get_load_balancer_listeners
    get_load_balancer_health_checks
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

  def resource_id_for_instance_id(id)
    # TODO(lsmola) we really need to get rid of the building our own emf_ref, it makes crosslinking impossible, parsing
    # the id string like this is suboptimal
    return nil unless id
    _, _, guid, _, resource_group, _, type, sub_type, name = id.split("/")
    resource_uid(guid,
                 resource_group.downcase,
                 "#{type.downcase}/#{sub_type.downcase}",
                 name)
  end

  def floating_ips
    @floating_ips ||= gather_data_for_this_region(@ips)
  end

  def load_balancers
    @load_balancers ||= gather_data_for_this_region(@lbs)
  end

  def get_cloud_networks
    cloud_networks = gather_data_for_this_region(@vns)
    process_collection(cloud_networks, :cloud_networks) { |cloud_network| parse_cloud_network(cloud_network) }
  end

  def get_cloud_subnets(cloud_network)
    subnets = cloud_network.properties.subnets
    process_collection(subnets, :cloud_subnets, false) { |subnet| parse_cloud_subnet(subnet) }
  end

  def get_security_groups
    security_groups = gather_data_for_this_region(@nsg)
    process_collection(security_groups, :security_groups) { |sg| parse_security_group(sg) }
  end

  def get_vm_security_groups(instance)
    get_vm_nics(instance).collect do |nic|
      sec_id = nic.properties.try(:network_security_group).try(:id)
      @data_index.fetch_path(:security_groups, sec_id) if sec_id
    end.compact
  end

  def get_network_ports
    process_collection(network_interfaces, :network_ports) { |n| parse_network_port(n) }
  end

  def get_floating_ips
    process_collection(floating_ips, :floating_ips) { |n| parse_floating_ip(n) }
  end

  def get_load_balancers
    process_collection(load_balancers, :load_balancers) { |lb| parse_load_balancer(lb) }
  end

  def get_load_balancer_pools
    @data[:load_balancer_pool_members] = []

    load_balancers.each do |lb|
      process_collection(lb.properties["backendAddressPools"], :load_balancer_pools) do |pool|
        parse_load_balancer_pool(pool)
      end
    end
  end

  def get_load_balancer_listeners
    load_balancers.each do |lb|
      process_collection(lb.properties["loadBalancingRules"], :load_balancer_listeners) do |listener|
        parse_load_balancer_listener(lb, listener)
      end
    end
  end

  def get_load_balancer_health_checks
    load_balancers.each do |lb|
      process_collection(lb.properties["probes"], :load_balancer_health_checks) do |health_check|
        parse_load_balancer_health_check(lb, health_check)
      end
    end
  end

  def get_heath_check_listener_and_members(health_check)
    health_check_members   = []
    matched_listener       = nil

    health_check.properties["loadBalancingRules"].to_a.each do |health_check_listener|
      matched_listener = @data.fetch_path(:load_balancer_listeners).detect do |listener|
        listener[:ems_ref] == health_check_listener["id"]
      end
      if matched_listener
        get_health_check_members(matched_listener, health_check_members)
        break
      end
    end

    return matched_listener, health_check_members
  end

  def get_health_check_members(matched_listener, health_check_members)
    matched_listener[:load_balancer_listener_pools].each do |listener_pool|
      listener_pool[:load_balancer_pool][:load_balancer_pool_member_pools].collect do |p|
        health_check_members << parse_health_check_member(p[:load_balancer_pool_member])
      end
    end

    health_check_members
  end

  def parse_load_balancer_pool(pool)
    uid = pool.id

    new_result = {
      :type                            => self.class.load_balancer_pool_type,
      :ems_ref                         => uid,
      :name                            => pool.name,
      :load_balancer_pool_member_pools => parse_load_balancer_pool_members(pool)
    }

    return uid, new_result
  end

  def parse_load_balancer_pool_members(pool)
    load_balancer_pool_members = []

    pool["properties"]["backendIPConfigurations"].to_a.each do |ipconfig|
      uid      = ipconfig.id
      nic_id   = @data_index.fetch_path(:nic_ipconfig_mapping, uid)
      instance = @data_index.fetch_path(:network_ports, nic_id)[:device]

      new_result = {
        :type    => self.class.load_balancer_pool_member_type,
        :ems_ref => uid,
        :vm      => instance
      }

      store_member_in_data_hashes(uid, new_result)
      load_balancer_pool_members << {:load_balancer_pool_member => new_result}
    end
    load_balancer_pool_members
  end

  def store_member_in_data_hashes(uid, member)
    if @data_index.fetch_path(:load_balancer_pool_members, uid).blank?
      @data_index.store_path(:load_balancer_pool_members, uid, member)
      @data[:load_balancer_pool_members] << member
    end
  end

  def parse_load_balancer_health_check(lb, health_check)
    uid = health_check.id
    health_check_listener, health_check_members = get_heath_check_listener_and_members(health_check)

    new_result = {
      :type                               => self.class.load_balancer_health_check_type,
      :ems_ref                            => uid,
      :protocol                           => health_check.properties["protocol"],
      :port                               => health_check.properties["port"],
      :interval                           => health_check.properties["intervalInSeconds"],
      :url_path                           => health_check.properties["requestPath"],
      :load_balancer                      => @data_index.fetch_path(:load_balancers, lb.id),
      :load_balancer_listener             => health_check_listener,
      :load_balancer_health_check_members => health_check_members
    }

    return uid, new_result
  end

  def parse_health_check_member(member)
    {
      :load_balancer_pool_member => @data_index.fetch_path(:load_balancer_pool_members, member[:ems_ref]),
    }
  end

  def parse_cloud_network(cloud_network)
    cloud_subnets = get_cloud_subnets(cloud_network).collect do |raw_subnet|
      @data_index.fetch_path(:cloud_subnets, raw_subnet.id)
    end

    uid = cloud_network.id

    new_result = {
      :type                => self.class.cloud_network_type,
      :ems_ref             => uid,
      :name                => cloud_network.name,
      :cidr                => cloud_network.properties.address_space.address_prefixes.join(", "),
      :enabled             => true,
      :cloud_subnets       => cloud_subnets,
      :orchestration_stack => parent_manager_fetch_path(:orchestration_stacks_resources, uid).try(:stack),
    }

    return uid, new_result
  end

  def parse_cloud_subnet(subnet)
    uid = subnet.id
    new_result = {
      :type              => self.class.cloud_subnet_type,
      :ems_ref           => uid,
      :name              => subnet.name,
      :cidr              => subnet.properties.address_prefix,
      :availability_zone => parent_manager_fetch_path(:availability_zones, 'default'),
    }
    return uid, new_result
  end

  def parse_security_group(security_group)
    uid = security_group.id

    description = [
      security_group.resource_group,
      security_group.location
    ].join('-')

    new_result = {
      :type           => self.class.security_group_type,
      :ems_ref        => uid,
      :name           => security_group.name,
      :description    => description,
      :firewall_rules => parse_firewall_rules(security_group)
    }

    return uid, new_result
  end

  def parse_firewall_rules(security_group)
    security_group.properties.security_rules.map do |rule|
      {
        :name                  => rule.name,
        :host_protocol         => rule.properties.protocol.upcase,
        :port                  => rule.properties.destination_port_range.split('-').first,
        :end_port              => rule.properties.destination_port_range.split('-').last,
        :direction             => rule.properties.direction,
        :source_ip_range       => rule.properties.source_address_prefix,
        :source_security_group => @data_index.fetch_path(:security_groups, security_group.id)
      }
    end
  end

  def parse_load_balancer(lb)
    name = lb.name
    uid  = lb.id

    new_result = {
      :type    => self.class.load_balancer_type,
      :ems_ref => uid,
      :name    => name,
    }

    return uid, new_result
  end

  def parse_load_balancer_listener(lb, listener)
    uid           = listener["id"]
    pool_id       = listener.properties["backendAddressPool"]["id"]
    pool          = @data_index.fetch_path(:load_balancer_pools, pool_id)
    backend_port  = listener.properties["backendPort"].to_i
    frontend_port = listener.properties["frontendPort"].to_i

    new_result = {
      :type                         => self.class.load_balancer_listener_type,
      :ems_ref                      => uid,
      :load_balancer_protocol       => listener.properties["protocol"],
      :load_balancer_port_range     => (backend_port..backend_port),
      :instance_protocol            => listener.properties["protocol"],
      :instance_port_range          => (frontend_port..frontend_port),
      :load_balancer                => @data_index.fetch_path(:load_balancers, lb.id),
      :load_balancer_listener_pools => [{:load_balancer_pool => pool }]
    }

    return uid, new_result
  end

  def floating_ip_network_port_id(ip)
    # TODO(lsmola) NetworkManager, we need to model ems_ref in model CloudSubnetNetworkPort and relate floating
    # ip to that model
    # For now cutting last 2 / from the id, to get just the id of the network_port. ID looks like:
    # /subscriptions/{guid}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/networkInterfaces/vm1nic1/ipConfigurations/ip1
    # where id of the network port is
    # /subscriptions/{guid}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/networkInterfaces/vm1nic1
    cloud_subnet_network_port_id = ip.properties.try(:ip_configuration).try(:id)
    cloud_subnet_network_port_id.split("/")[0..-3].join("/") if cloud_subnet_network_port_id
  end

  def parse_floating_ip(ip)
    uid = ip.id

    new_result = {
      :type             => self.class.floating_ip_type,
      :ems_ref          => uid,
      :status           => ip.properties.try(:provisioning_state),
      :address          => ip.properties.try(:ip_address) || ip.name,
      # TODO(lsmola) get :fixed_ip_address from the correct related cloud_subnet_network_port
      :fixed_ip_address => @data_index.fetch_path(:network_ports,
                                                  floating_ip_network_port_id(ip),
                                                  :cloud_subnet_network_ports).try(:first).try(:[], :address),
      :network_port     => @data_index.fetch_path(:network_ports, floating_ip_network_port_id(ip)),
      :vm               => @data_index.fetch_path(:network_ports,
                                                  floating_ip_network_port_id(ip),
                                                  :device),
    }
    return uid, new_result
  end

  def parse_cloud_subnet_network_port(network_port)
    {
      :address      => network_port.properties.private_ip_address,
      :cloud_subnet => @data_index.fetch_path(:cloud_subnets, network_port.properties.subnet.id)
    }
  end

  def parse_network_port(network_port)
    uid                        = network_port.id
    cloud_subnet_network_ports = network_port.properties.ip_configurations.map do |x|
      parse_cloud_subnet_network_port(x)
    end

    network_port.properties.ip_configurations.each do |ipconfig|
      @data_index.store_path(:nic_ipconfig_mapping, ipconfig.id, uid)
    end

    vm_id  = resource_id_for_instance_id(network_port.properties.try(:virtual_machine).try(:id))
    device = parent_manager_fetch_path(:vms, vm_id)

    security_groups = [@data_index.fetch_path(
      :security_groups,
      network_port.properties.try(:network_security_group).try(:id))].compact

    new_result = {
      :type                       => self.class.network_port_type,
      :name                       => uid,
      :ems_ref                    => uid,
      :status                     => network_port.properties.try(:provisioning_state),
      :mac_address                => network_port.properties.try(:mac_address),
      :device_ref                 => network_port.properties.try(:virtual_machine).try(:id),
      :device                     => device,
      :cloud_subnet_network_ports => cloud_subnet_network_ports,
      :security_groups            => security_groups,
    }
    return uid, new_result
  end

  class << self
    def load_balancer_type
      ManageIQ::Providers::Azure::NetworkManager::LoadBalancer.name
    end

    def load_balancer_pool_type
      ManageIQ::Providers::Azure::NetworkManager::LoadBalancerPool.name
    end

    def load_balancer_pool_member_type
      ManageIQ::Providers::Azure::NetworkManager::LoadBalancerPoolMember.name
    end

    def load_balancer_listener_type
      ManageIQ::Providers::Azure::NetworkManager::LoadBalancerListener.name
    end

    def load_balancer_health_check_type
      ManageIQ::Providers::Azure::NetworkManager::LoadBalancerHealthCheck.name
    end

    def security_group_type
      ManageIQ::Providers::Azure::NetworkManager::SecurityGroup.name
    end

    def network_router_type
      ManageIQ::Providers::Azure::NetworkManager::NetworkRouter.name
    end

    def cloud_network_type
      ManageIQ::Providers::Azure::NetworkManager::CloudNetwork.name
    end

    def cloud_subnet_type
      ManageIQ::Providers::Azure::NetworkManager::CloudSubnet.name
    end

    def floating_ip_type
      ManageIQ::Providers::Azure::NetworkManager::FloatingIp.name
    end

    def network_port_type
      ManageIQ::Providers::Azure::NetworkManager::NetworkPort.name
    end
  end
end
