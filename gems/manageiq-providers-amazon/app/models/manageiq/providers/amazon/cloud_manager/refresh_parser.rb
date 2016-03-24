# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

class ManageIQ::Providers::Amazon::CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
  include ManageIQ::Providers::Amazon::HelperMethods

  def initialize(ems, options = nil)
    @ems                 = ems
    @aws_ec2             = ems.connect
    @aws_cloud_formation = ems.connect(:service => :CloudFormation)
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
    get_private_images if @options["get_private_images"]
    get_shared_images  if @options["get_shared_images"]
    get_public_images  if @options["get_public_images"]
    get_instances
    $aws_log.info("#{log_header}...Complete")

    filter_unused_disabled_flavors

    @data
  end

  private

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
      :ipaddress => instance.private_ip_address.presence,
      :hostname  => instance.private_dns_name.presence
    }.delete_nils

    public_network = {
      :ipaddress => instance.public_ip_address.presence,
      :hostname  => instance.public_dns_name.presence
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
      child_stacks << physical_id if resource.resource_type == "AWS::CloudFormation::Stack"
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
      :orderable   => false
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
end
