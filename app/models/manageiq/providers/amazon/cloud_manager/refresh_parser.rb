# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

class ManageIQ::Providers::Amazon::CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
  def self.ems_inv_to_hashes(ems, options = nil)
    new(ems, options).ems_inv_to_hashes
  end

  def initialize(ems, options = nil)
    @ems                 = ems
    @aws_ec2             = ems.ec2
    @aws_cloud_formation = ems.cloud_formation
    @data                = {}
    @data_index          = {}
    @known_flavors       = Set.new

    @options    = options || {}
    # Default the collection of images unless explicitly declined
    @options["get_private_images"] = true  unless @options.key?("get_private_images")
    @options["get_shared_images"]  = true  unless @options.key?("get_shared_images")
    @options["get_public_images"]  = false unless @options.key?("get_public_images")
  end

  def ems_inv_to_hashes
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

    $aws_log.info("#{log_header}...")
    get_flavors
    get_availability_zones
    get_key_pairs
    get_stacks
    get_cloud_networks
    get_security_groups
    get_private_images if @options["get_private_images"]
    get_shared_images  if @options["get_shared_images"]
    get_public_images  if @options["get_public_images"]
    get_instances
    get_floating_ips
    $aws_log.info("#{log_header}...Complete")

    filter_unused_disabled_flavors

    @data
  end

  private

  def security_groups
    @security_groups ||= @aws_ec2.security_groups
  end

  def get_flavors
    process_collection(ManageIQ::Providers::Amazon::InstanceTypes.all, :flavors) { |flavor| parse_flavor(flavor) }
  end

  def get_availability_zones
    azs = @aws_ec2.client.describe_availability_zones[:availability_zones]
    process_collection(azs, :availability_zones) { |az| parse_availability_zone(az) }
  end

  def get_key_pairs
    kps = @aws_ec2.client.describe_key_pairs[:key_pairs]
    process_collection(kps, :key_pairs) { |kp| parse_key_pair(kp) }
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

  def get_private_images
    get_images(
      @aws_ec2.client.describe_images(:owners  => [:self],
                                      :filters => [{:name   => "image-type",
                                                    :values => ["machine"]}])[:images])
  end

  def get_shared_images
    get_images(
      @aws_ec2.client.describe_images(:executable_users => [:self],
                                      :filters          => [{:name   => "image-type",
                                                             :values => ["machine"]}])[:images])
  end

  def get_public_images
    get_images(
      @aws_ec2.client.describe_images(:executable_users => [:all],
                                      :filters          => [{:name   => "image-type",
                                                             :values => ["machine"]}])[:images], true)
  end

  def get_images(images, is_public = false)
    process_collection(images, :vms) { |image| parse_image(image, is_public) }
  end

  def get_stacks
    stacks = @aws_cloud_formation.stacks
    process_collection(stacks, :orchestration_stacks) { |stack| parse_stack(stack) }
    update_nested_stack_relations
  end

  def get_stack_parameters(stack_id, parameters)
    process_collection(parameters, :orchestration_stack_parameters) do |param_key, param_val|
      parse_stack_parameter(param_key, param_val, stack_id)
    end
  end

  def get_stack_outputs(stack_id, outputs)
    process_collection(outputs, :orchestration_stack_outputs) do |output|
      parse_stack_output(output, stack_id)
    end
  end

  def get_stack_resources(resources)
    process_collection(resources, :orchestration_stack_resources) { |resource| parse_stack_resource(resource) }
  end

  def get_stack_template(stack)
    process_collection([stack], :orchestration_templates) { |the_stack| parse_stack_template(the_stack) }
  end

  def get_instances
    instances = @aws_ec2.instances
    process_collection(instances, :vms) { |instance| parse_instance(instance) }
  end

  def get_floating_ips
    ips = @aws_ec2.client.describe_addresses.addresses
    process_collection(ips, :floating_ips) { |ip| parse_floating_ip(ip) }
  end

  def process_collection(collection, key)
    @data[key] ||= []

    collection.each do |item|
      uid, new_result = yield(item)
      next if uid.nil?

      @data[key] << new_result
      @data_index.store_path(key, uid, new_result)
    end
  end

  def parse_flavor(flavor)
    name = uid = flavor[:name]

    cpus = flavor[:vcpu]

    new_result = {
      :type                     => ManageIQ::Providers::Amazon::CloudManager::Flavor.name,
      :ems_ref                  => uid,
      :name                     => name,
      :description              => flavor[:description],
      :enabled                  => !flavor[:disabled],
      :cpus                     => cpus,
      :cpu_cores                => 1,
      :memory                   => flavor[:memory],
      :supports_32_bit          => flavor[:architecture].include?(:i386),
      :supports_64_bit          => flavor[:architecture].include?(:x86_64),
      :supports_hvm             => flavor[:virtualization_type].include?(:hvm),
      :supports_paravirtual     => flavor[:virtualization_type].include?(:paravirtual),
      :block_storage_based_only => flavor[:ebs_only],
      :cloud_subnet_required    => flavor[:vpc_only],
      :ephemeral_disk_size      => flavor[:instance_store_size],
      :ephemeral_disk_count     => flavor[:instance_store_volumes]
    }

    return uid, new_result
  end

  def parse_availability_zone(az)
    name = uid = az.zone_name

    # power_state = (az.state == :available) ? "on" : "off",

    new_result = {
      :type    => ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.name,
      :ems_ref => uid,
      :name    => name,
    }

    return uid, new_result
  end

  def parse_key_pair(kp)
    name = uid = kp.key_name

    new_result = {
      :type        => self.class.key_pair_type,
      :name        => name,
      :fingerprint => kp.key_fingerprint
    }

    return uid, new_result
  end

  def self.key_pair_type
    ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair.name
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
      :ems_ref             => uid,
      :name                => name,
      :cidr                => vpc.cidr_block,
      :status              => status,
      :enabled             => true,

      :orchestration_stack => @data_index.fetch_path(:orchestration_stacks,
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
      :ems_ref           => uid,
      :name              => name,
      :cidr              => subnet.cidr_block,
      :status            => subnet.state.try(:to_s),
      :availability_zone => @data_index.fetch_path(:availability_zones, subnet.availability_zone)
    }

    return uid, new_result
  end

  def self.security_group_type
    ManageIQ::Providers::Amazon::CloudManager::SecurityGroup.name
  end

  def parse_security_group(sg)
    uid = sg.group_id

    new_result = {
      :type                => self.class.security_group_type,
      :ems_ref             => uid,
      :name                => sg.group_name,
      :description         => sg.description.try(:truncate, 255),
      :cloud_network       => @data_index.fetch_path(:cloud_networks, sg.vpc_id),
      :orchestration_stack => @data_index.fetch_path(:orchestration_stacks,
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

  def parse_image(image, is_public)
    uid      = image.image_id
    location = image.image_location
    guest_os = (image.platform == "windows") ? "windows" : "linux"

    name     = get_from_tags(image, :name)
    name ||= image.name
    name ||= $1 if location =~ /^(.+?)(\.(image|img))?\.manifest\.xml$/
    name ||= uid

    new_result = {
      :type               => ManageIQ::Providers::Amazon::CloudManager::Template.name,
      :uid_ems            => uid,
      :ems_ref            => uid,
      :name               => name,
      :location           => location,
      :vendor             => "amazon",
      :raw_power_state    => "never",
      :template           => true,
      # the is_public flag here avoids having to make an additional API call
      # per image, since we already know whether it's a public image
      :publicly_available => is_public,

      :hardware           => {
        :guest_os            => guest_os,
        :bitness             => architecture_to_bitness(image.architecture),
        :virtualization_type => image.virtualization_type,
        :root_device_type    => image.root_device_type,
      },
    }

    return uid, new_result
  end

  def parse_instance(instance)
    status = instance.state.name
    return if @options["ignore_terminated_instances"] && status.to_sym == :terminated

    uid    = instance.id
    name   = get_from_tags(instance, :name)
    name ||= uid

    flavor_uid = instance.instance_type
    @known_flavors << flavor_uid
    flavor = @data_index.fetch_path(:flavors, flavor_uid) ||
             @data_index.fetch_path(:flavors, "unknown")

    private_network = {
      :ipaddress => instance.private_ip_address,
      :hostname  => instance.private_dns_name
    }.delete_nils

    public_network = {
      :ipaddress => instance.public_ip_address,
      :hostname  => instance.public_dns_name
    }.delete_nils

    parent_image = @data_index.fetch_path(:vms, instance.image_id)
    if parent_image
      virtualization_type = parent_image.fetch_path(:hardware, :virtualization_type)
      root_device_type    = parent_image.fetch_path(:hardware, :root_device_type)
    end

    new_result = {
      :type                => ManageIQ::Providers::Amazon::CloudManager::Vm.name,
      :uid_ems             => uid,
      :ems_ref             => uid,
      :name                => name,
      :vendor              => "amazon",
      :raw_power_state     => status,

      :hardware            => {
        :bitness              => architecture_to_bitness(instance.architecture),
        :virtualization_type  => virtualization_type,
        :root_device_type     => root_device_type,
        :cpu_sockets          => flavor[:cpus],
        :cpu_cores_per_socket => 1,
        :cpu_total_cores      => flavor[:cpus],
        :memory_mb            => flavor[:memory] / 1.megabyte,
        :disk_capacity        => flavor[:ephemeral_disk_size],
        :disks                => [], # Filled in later conditionally on flavor
        :networks             => [], # Filled in later conditionally on what's available
      },

      :availability_zone   => @data_index.fetch_path(:availability_zones, instance.placement.availability_zone),
      :flavor              => flavor,
      :cloud_network       => @data_index.fetch_path(:cloud_networks, instance.vpc_id),
      :cloud_subnet        => @data_index.fetch_path(:cloud_subnets, instance.subnet_id),
      :key_pairs           => [@data_index.fetch_path(:key_pairs, instance.key_name)].compact,
      :security_groups     => instance.security_groups.to_a.collect do |sg|
        @data_index.fetch_path(:security_groups, sg.group_id)
      end.compact,
      :orchestration_stack => @data_index.fetch_path(:orchestration_stacks,
                                                     get_from_tags(instance, "aws:cloudformation:stack-id")),
    }
    new_result[:location] = public_network[:hostname] if public_network[:hostname]
    new_result[:hardware][:networks] << private_network.merge(:description => "private") unless private_network.blank?
    new_result[:hardware][:networks] << public_network.merge(:description => "public")   unless public_network.blank?

    if parent_image
      new_result[:parent_vm] = parent_image
      new_result.store_path(:hardware, :guest_os, parent_image.fetch_path(:hardware, :guest_os))
    end

    if flavor[:ephemeral_disk_count] > 0
      disks = new_result[:hardware][:disks]
      single_disk_size = flavor[:ephemeral_disk_size] / flavor[:ephemeral_disk_count]
      flavor[:ephemeral_disk_count].times do |i|
        add_instance_disk(disks, single_disk_size, i, "Disk #{i}")
      end
    end

    return uid, new_result
  end

  def parse_floating_ip(ip)
    address = uid = ip.public_ip

    associated_vm = @data[:vms].detect do |v|
      v.fetch_path(:hardware, :networks).to_miq_a.detect do |n|
        n[:description] == "public" && n[:ipaddress] == address
      end
    end

    new_result = {
      :type               => ManageIQ::Providers::Amazon::CloudManager::FloatingIp.name,
      :ems_ref            => uid,
      :address            => address,
      :cloud_network_only => ip.domain["vpc"] ? true : false,

      :vm                 => associated_vm
    }

    return uid, new_result
  end

  def parse_stack(stack)
    uid = stack.stack_id.to_s
    child_stacks, resources = find_stack_resources(stack)
    new_result = {
      :type                   => ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.name,
      :ems_ref                => uid,
      :name                   => stack.name,
      :description            => stack.description,
      :status                 => stack.stack_status,
      :status_reason          => stack.stack_status_reason,
      :children               => child_stacks,
      :resources              => resources,
      :outputs                => find_stack_outputs(stack),
      :parameters             => find_stack_parameters(stack),

      :orchestration_template => find_stack_template(stack)
    }
    return uid, new_result
  end

  def find_stack_template(stack)
    get_stack_template(stack)
    @data_index.fetch_path(:orchestration_templates, stack.stack_id)
  end

  def find_stack_parameters(stack)
    raw_parameters = stack.parameters.each_with_object({}) { |sp, hash| hash[sp.parameter_key] = sp.parameter_value }
    get_stack_parameters(stack.stack_id, raw_parameters)
    raw_parameters.collect do |parameter|
      @data_index.fetch_path(:orchestration_stack_parameters, compose_ems_ref(stack.stack_id, parameter[0]))
    end
  end

  def find_stack_outputs(stack)
    raw_outputs = stack.outputs
    get_stack_outputs(stack.stack_id, raw_outputs)
    raw_outputs.collect do |output|
      @data_index.fetch_path(:orchestration_stack_outputs, compose_ems_ref(stack.stack_id, output.output_key))
    end
  end

  def find_stack_resources(stack)
    raw_resources = stack.resource_summaries.entries

    # physical_resource_id can be empty if the resource was not successfully created; ignore such
    raw_resources.reject! { |r| r.physical_resource_id.nil? }

    get_stack_resources(raw_resources)

    child_stacks = []
    resources = raw_resources.collect do |resource|
      physical_id = resource.physical_resource_id
      child_stacks << physical_id if resource.resource_type == "Aws::CloudFormation::Stack"
      @data_index.fetch_path(:orchestration_stack_resources, physical_id)
    end

    return child_stacks, resources
  end

  def parse_stack_template(stack)
    # Only need a temporary unique identifier for the template. Using the stack id is the cheapest way.
    uid = stack.stack_id
    new_result = {
      :type        => "OrchestrationTemplateCfn",
      :name        => stack.name,
      :description => stack.description,
      :content     => stack.client.get_template(:stack_name => stack.name).template_body,
    }
    return uid, new_result
  end

  def parse_stack_parameter(param_key, param_val, stack_id)
    uid = compose_ems_ref(stack_id, param_key)
    new_result = {
      :ems_ref => uid,
      :name    => param_key,
      :value   => param_val
    }
    return uid, new_result
  end

  def parse_stack_output(output, stack_id)
    uid = compose_ems_ref(stack_id, output.output_key)
    new_result = {
      :ems_ref     => uid,
      :key         => output.output_key,
      :value       => output.output_value,
      :description => output.description
    }
    return uid, new_result
  end

  def parse_stack_resource(resource)
    uid = resource.physical_resource_id
    new_result = {
      :ems_ref                => uid,
      :name                   => resource.logical_resource_id,
      :logical_resource       => resource.logical_resource_id,
      :physical_resource      => uid,
      :resource_category      => resource.resource_type,
      :resource_status        => resource.resource_status,
      :resource_status_reason => resource.resource_status_reason,
      :last_updated           => resource.last_updated_timestamp
    }
    return uid, new_result
  end

  #
  # Helper methods
  #
  ARCHITECTURE_TO_BITNESS = {
    :i386   => 32,
    :x86_64 => 64,
  }.freeze

  def architecture_to_bitness(arch)
    ARCHITECTURE_TO_BITNESS[arch.to_sym]
  end

  # Remap from children to parent
  def update_nested_stack_relations
    @data[:orchestration_stacks].each do |stack|
      stack[:children].each do |child_stack_id|
        child_stack = @data_index.fetch_path(:orchestration_stacks, child_stack_id)
        child_stack[:parent] = stack if child_stack
      end
      stack.delete(:children)
    end
  end

  def get_from_tags(resource, item)
    resource.tags.detect { |tag, _| tag.key.downcase == item.to_s.downcase }.try(:value)
  end

  def add_instance_disk(disks, size, name, location)
    super(disks, size, name, location, "amazon")
  end

  # Compose an ems_ref combining some existing keys
  def compose_ems_ref(*keys)
    keys.join('_')
  end
end
