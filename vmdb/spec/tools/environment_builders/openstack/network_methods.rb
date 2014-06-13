module NetworkMethods
  def fog_network
    @fog_network ||= begin
      connect("Network")
    rescue MiqException::ServiceNotAvailable
      connect
    end
  end

  def network_service
    @network_service ||= fog_network.in_namespace?(Fog::Network) ? :neutron : :nova
  end

  def find_or_create_networks
    return unless network_service == :neutron

    settings[:network][:network].each do |k, v|
      key       = "Network#{k.capitalize}"
      data      = v.merge(:name => "EmsRefreshSpec-#{key}")
      network   = send("find_network_#{network_service}", data)
      network ||= send("create_network_#{network_service}", data)

      instance_variable_set("@#{key.underscore}", network)
    end
  end

  def find_or_create_subnet
    return unless network_service == :neutron

    settings[:network][:subnet].each do |k, v|
      key       = "Subnet#{k.capitalize}"
      network   = instance_variable_get("@network_#{k}")
      data      = v.merge(:name => "EmsRefreshSpec-#{key}", :network_id => network.id)
      subnet    = send("find_subnet_#{network_service}", data)
      subnet  ||= send("create_subnet_#{network_service}", data)

      instance_variable_set("@#{key.underscore}", subnet)
    end
  end

  def find_or_create_router
    return unless network_service == :neutron

    @router   = send("find_router_#{network_service}", :name => "EmsRefreshSpec-Router")
    @router ||= send("create_router_#{network_service}", :name => "EmsRefreshSpec-Router")
  end

  def find_or_create_floating_ip
    data = settings[:network][:floating_ip]
    data.merge(:floating_network_id => @network_public.id) if network_service == :neutron

    @floating_ip ||= send("find_floating_ip_#{network_service}", data)
    @floating_ip ||= send("create_floating_ip_#{network_service}", data)
  end

  def find_or_create_firewall_rules(sg)
    rules = settings[:network][:security_group_rules]

    rules.each do |attributes|
      attributes[:remote_group_id] = sg.id if attributes[:remote_group_id]
      obj = send("find_firewall_rule_#{network_service}", sg.id, attributes)
      obj || send("create_firewall_rule_#{network_service}", sg.id, attributes)
    end
  end

  private

  def find_network_neutron(data)
    collection = fog_network.networks
    puts "Finding network #{data[:name]} in #{collection.class.name}"
    collection.find { |i| i.name == data[:name] }
  end

  def create_network_neutron(data)
    collection = fog_network.networks
    puts "Creating network #{data[:name]} in #{collection.class.name}"
    collection.create(data)
  end

  def find_subnet_neutron(data)
    collection = fog_network.subnets
    puts "Finding subnet #{data[:name]} in #{collection.class.name}"
    collection.find { |i| i.name == data[:name] }
  end

  def create_subnet_neutron(data)
    collection = fog_network.subnets
    puts "Creating subnet #{data[:name]} in #{collection.class.name}"
    collection.create(data)
  end

  def find_router_neutron(data)
    collection = fog_network.routers
    puts "Finding router #{data[:name]} in #{collection.class.name}"
    collection.find { |i| i.name == data[:name] }
  end

  def create_router_neutron(data)
    collection = fog_network.routers
    puts "Creating router #{data[:name]} in #{collection.class.name}"

    # TODO: enhance Fog Neutron router support
    puts "Routers must be created manually.  Please run:"
    puts "  neutron router-create #{data[:name]}"
    puts "  neutron router-gateway-set #{data[:name]} #{@network_public.name}"
    puts "  neutron router-interface-add #{data[:name]} #{@subnet_private.name}"
    exit 1
  end

  def find_floating_ip_neutron(data)
    collection = fog_network.floating_ips
    puts "Finding address in #{collection.class.name}"
    collection.detect { |i| i.floating_ip_address == data[:floating_ip_address] }.try(:floating_ip_address)
  end

  def create_floating_ip_neutron(data)
    collection = fog_network.floating_ips
    puts "Creating address against #{collection.class.name}"
    collection.create(data.merge(:floating_network_id => @network_public.id)).floating_ip_address
  end

  def find_floating_ip_nova(data)
    collection = fog_network.addresses
    puts "Finding address in #{collection.class.name}"
    collection.detect { |i| i.ip == data[:ip] }.try(&:ip)
  end

  def create_floating_ip_nova(data)
    collection = fog_network.addresses
    puts "Creating address against #{collection.class.name}"
    collection.create(data).ip
  end

  def find_firewall_rule_nova(sg_id, attributes)
    collection = @fog_network.security_groups.find { |i| i.id == sg_id }.security_group_rules

    rule = {:ip_range => {}}.merge(attributes)
    rule[:parent_group_id] = sg_id

    find(collection, rule)
  end

  def create_firewall_rule_nova(sg_id, attributes)
    sg         = @fog_network.security_groups.find { |i| i.id == sg_id }
    collection = sg.security_group_rules
    puts "Creating security group rule #{attributes.inspect} in #{collection.class.name}"
    attributes[:parent_group_id]  = sg_id
    attributes[:group]            = sg_id if attributes[:group]
    collection.create(attributes)
  end

  def find_firewall_rule_neutron(sg_id, attributes)
    collection = @fog_network.security_groups.find { |i| i.id == sg_id }.security_group_rules

    rule = {
      :port_range_min   => nil,
      :port_range_max   => nil,
      :remote_ip_prefix => nil,
      :remote_group_id  => nil
    }.merge(attributes)
    rule[:remote_group_id] = sg_id if attributes[:remote_group_id]

    find(collection, rule)
  end

  def create_firewall_rule_neutron(sg_id, attributes)
    collection = @fog_network.security_groups.find { |i| i.id == sg_id }.security_group_rules
    puts "Creating security group rule #{attributes.inspect} in #{collection.class.name}"
    attributes[:security_group_id]  = sg_id
    attributes[:remote_group_id]    = sg_id if attributes[:remote_group_id]
    collection.create(attributes)
  end
end
