# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

class ManageIQ::Providers::Amazon::NetworkManager::RefreshParser
  include ManageIQ::Providers::Amazon::RefreshHelperMethods

  def initialize(ems, options = nil)
    @ems        = ems
    @aws_ec2    = ems.connect
    @data       = {}
    @data_index = {}
    @options    = options || {}
  end

  def ems_inv_to_hashes
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

    $aws_log.info("#{log_header}...")
    # The order of the below methods does matter, because there are inner dependencies of the data!
    get_cloud_networks
    get_security_groups
    get_network_ports
    get_floating_ips
    $aws_log.info("#{log_header}...Complete")

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

  def security_groups
    @security_groups ||= @aws_ec2.security_groups
  end

  def get_cloud_networks
    vpcs = @aws_ec2.client.describe_vpcs[:vpcs]
    process_collection(vpcs, :cloud_networks) { |vpc| parse_cloud_network(vpc) }
  end

  def get_cloud_subnets(subnets)
    process_collection(subnets, :cloud_subnets) { |s| parse_cloud_subnet(s) }
  end

  def get_security_groups
    process_collection(security_groups, :security_groups) { |sg| parse_security_group(sg) }
    get_firewall_rules
  end

  def get_firewall_rules
    security_groups.each do |sg|
      new_sg = @data_index.fetch_path(:security_groups, sg.group_id)
      new_sg[:firewall_rules] = get_inbound_firewall_rules(sg) + get_outbound_firewall_rules(sg)
    end
  end

  def get_inbound_firewall_rules(sg)
    sg.ip_permissions.collect { |perm| parse_firewall_rule(perm, "inbound") }.flatten
  end

  def get_outbound_firewall_rules(sg)
    sg.ip_permissions_egress.collect { |perm| parse_firewall_rule(perm, "outbound") }.flatten
  end

  def get_floating_ips
    ips = @aws_ec2.client.describe_addresses.addresses
    # Take only floating ips that are not already in stored by ec2 flaoting_ips
    ips = ips.select do |floating_ip|
      floating_ip_id = floating_ip.allocation_id.blank? ? floating_ip.public_ip : floating_ip.allocation_id
      @data_index.fetch_path(:floating_ips, floating_ip_id).nil?
    end
    process_collection(ips, :floating_ips) { |ip| parse_floating_ip(ip) }
  end

  def get_public_ips(network_ports)
    public_ips = []
    network_ports.each do |network_port|
      network_port.private_ip_addresses.each do |private_address|
        if private_address.association && !(public_ip = private_address.association.public_ip).blank? &&
           private_address.association.allocation_id.blank?

          unless @data_index.fetch_path(:floating_ips, public_ip)
            public_ips << {
              :network_port_id    => network_port.network_interface_id,
              :private_ip_address => private_address.private_ip_address,
              :public_ip_address  => public_ip
            }
          end
        end
      end
    end
    process_collection(public_ips, :floating_ips) { |public_ip| parse_public_ip(public_ip) }
  end

  def get_network_ports
    network_ports = @aws_ec2.client.describe_network_interfaces.network_interfaces
    instances     = @aws_ec2.instances.select { |instance| instance.network_interfaces.blank? }
    process_collection(network_ports, :network_ports) { |n| parse_network_port(n) }
    process_collection(instances, :network_ports) { |x| parse_network_port_inferred_from_instance(x) }
    process_collection(instances, :floating_ips) { |instance| parse_floating_ip_inferred_from_instance(instance) }
    get_public_ips(network_ports)
  end

  def parse_cloud_network(vpc)
    uid    = vpc.vpc_id

    name   = get_from_tags(vpc, :name)
    name ||= uid

    status  = (vpc.state == :available) ? "active" : "inactive"

    subnets = @aws_ec2.client.describe_subnets(:filters => [{:name => "vpc-id", :values => [vpc.vpc_id]}])[:subnets]
    get_cloud_subnets(subnets)
    cloud_subnets = subnets.collect { |s| @data_index.fetch_path(:cloud_subnets, s.subnet_id) }

    new_result = {
      :type                => self.class.cloud_network_type,
      :ems_ref             => uid,
      :name                => name,
      :cidr                => vpc.cidr_block,
      :status              => status,
      :enabled             => true,
      :orchestration_stack => parent_manager_fetch_path(:orchestration_stacks,
                                                        get_from_tags(vpc, "aws:cloudformation:stack-id")),
      :cloud_subnets       => cloud_subnets,
    }
    return uid, new_result
  end

  def parse_cloud_subnet(subnet)
    uid    = subnet.subnet_id

    name   = get_from_tags(subnet, :name)
    name ||= uid

    new_result = {
      :type              => self.class.cloud_subnet_type,
      :ems_ref           => uid,
      :name              => name,
      :cidr              => subnet.cidr_block,
      :status            => subnet.state.try(:to_s),
      :availability_zone => parent_manager_fetch_path(:availability_zones, subnet.availability_zone)
    }

    return uid, new_result
  end

  def parse_security_group(sg)
    uid = sg.group_id

    new_result = {
      :type                => self.class.security_group_type,
      :ems_ref             => uid,
      :name                => sg.group_name,
      :description         => sg.description.try(:truncate, 255),
      :cloud_network       => @data_index.fetch_path(:cloud_networks, sg.vpc_id),
      :orchestration_stack => parent_manager_fetch_path(:orchestration_stacks,
                                                        get_from_tags(sg, "aws:cloudformation:stack-id")),
    }
    return uid, new_result
  end

  # TODO: Should ICMP protocol values have their own 2 columns, or
  #   should they override port and end_port like the Amazon API.
  def parse_firewall_rule(perm, direction)
    ret = []

    common = {
      :direction     => direction,
      :host_protocol => perm.ip_protocol.to_s.upcase,
      :port          => perm.from_port,
      :end_port      => perm.to_port,
    }

    perm.user_id_group_pairs.each do |g|
      new_result = common.dup
      new_result[:source_security_group] = @data_index.fetch_path(:security_groups, g.group_id)
      ret << new_result
    end
    perm.ip_ranges.each do |r|
      new_result = common.dup
      new_result[:source_ip_range] = r.cidr_ip
      ret << new_result
    end

    ret
  end

  def parse_floating_ip(ip)
    cloud_network_only = ip.domain == "vpc" ? true : false
    address            = ip.public_ip
    uid                = cloud_network_only ? ip.allocation_id : ip.public_ip

    new_result = {
      :type               => self.class.floating_ip_type,
      :ems_ref            => uid,
      :address            => address,
      :fixed_ip_address   => ip.private_ip_address,
      :cloud_network_only => cloud_network_only,
      :network_port       => @data_index.fetch_path(:network_ports, ip.network_interface_id),
      :vm                 => parent_manager_fetch_path(:vms, ip.instance_id)
    }

    return uid, new_result
  end

  def parse_floating_ip_inferred_from_instance(instance)
    address = uid = instance.public_ip_address

    new_result = {
      :type               => self.class.floating_ip_type,
      :ems_ref            => uid,
      :address            => address,
      :fixed_ip_address   => instance.private_ip_address,
      :cloud_network_only => false,
      :network_port       => @data_index.fetch_path(:network_ports, instance.id),
      :vm                 => parent_manager_fetch_path(:vms, instance.id)
    }

    return uid, new_result
  end

  def parse_public_ip(public_ip)
    address = uid = public_ip[:public_ip_address]
    new_result = {
      :type               => self.class.floating_ip_type,
      :ems_ref            => uid,
      :address            => address,
      :fixed_ip_address   => public_ip[:private_ip_address],
      :cloud_network_only => true,
      :network_port       => @data_index.fetch_path(:network_ports, public_ip[:network_port_id]),
      :vm                 => @data_index.fetch_path(:network_ports, public_ip[:network_port_id], :device)
    }

    return uid, new_result
  end

  def parse_cloud_subnet_network_port(cloud_subnet_network_port, subnet_id)
    {
      :address      => cloud_subnet_network_port.private_ip_address,
      :cloud_subnet => @data_index.fetch_path(:cloud_subnets, subnet_id)
    }
  end

  def parse_network_port(network_port)
    uid                        = network_port.network_interface_id
    # TODO(lsmola) AWS can have secondary private IP address assigned to the ENI, our current model does not allow that.
    # Probably the best fix is, to expand unique index of the cloud_subnet_network_ports to include address. Also we
    # need to expand our tests to include the secondary fixed IP. Then we can remove the .slice(0..0)
    cloud_subnet_network_ports = network_port.private_ip_addresses.slice(0..0).map do |x|
      parse_cloud_subnet_network_port(x, network_port.subnet_id)
    end
    device                     = parent_manager_fetch_path(:vms, network_port.try(:attachment).try(:instance_id))
    security_groups            = network_port.groups.blank? ? [] : network_port.groups.map do |x|
      @data_index.fetch_path(:security_groups, x.group_id)
    end

    new_result = {
      :type                       => self.class.network_port_type,
      :name                       => uid,
      :ems_ref                    => uid,
      :status                     => network_port.status,
      :mac_address                => network_port.mac_address,
      :device_owner               => network_port.try(:attachment).try(:instance_owner_id),
      :device_ref                 => network_port.try(:attachment).try(:instance_id),
      :device                     => device,
      :cloud_subnet_network_ports => cloud_subnet_network_ports,
      :security_groups            => security_groups,
    }
    return uid, new_result
  end

  def parse_network_port_inferred_from_instance(instance)
    # Create network_port placeholder for old EC2 instances, those do not have interface nor subnet nor VPC
    cloud_subnet_network_ports = [parse_cloud_subnet_network_port(instance, nil)]

    uid    = instance.id
    name   = get_from_tags(instance, :name)
    name ||= uid

    device = parent_manager_fetch_path(:vms, uid)

    new_result = {
      :type                       => self.class.network_port_type,
      :name                       => name,
      :ems_ref                    => uid,
      :status                     => nil,
      :mac_address                => nil,
      :device_owner               => nil,
      :device_ref                 => nil,
      :device                     => device,
      :cloud_subnet_network_ports => cloud_subnet_network_ports,
      :security_groups            => instance.security_groups.to_a.collect do |sg|
        @data_index.fetch_path(:security_groups, sg.group_id)
      end.compact,
    }
    return uid, new_result
  end

  class << self
    def security_group_type
      ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup.name
    end

    def network_router_type
      ManageIQ::Providers::Amazon::NetworkManager::NetworkRouter.name
    end

    def cloud_network_type
      ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork.name
    end

    def cloud_subnet_type
      ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet.name
    end

    def floating_ip_type
      ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.name
    end

    def network_port_type
      ManageIQ::Providers::Amazon::NetworkManager::NetworkPort.name
    end
  end
end
