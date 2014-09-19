# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

module EmsRefresh::Parsers
  class Ec2 < Cloud
    def self.ems_inv_to_hashes(ems, options = nil)
      self.new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, options = nil)
      @ems           = ems
      @connection    = ems.connect
      @data          = {}
      @data_index    = {}
      @known_flavors = Set.new

      @options    = options || {}
      # Default the collection of images unless explicitly declined
      @options["get_private_images"] = true  unless @options.has_key?("get_private_images")
      @options["get_shared_images"]  = true  unless @options.has_key?("get_shared_images")
      @options["get_public_images"]  = false unless @options.has_key?("get_public_images")
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $aws_log.info("#{log_header}...")
      AWS.memoize do
        get_flavors
        get_availability_zones
        get_key_pairs
        get_cloud_networks
        get_security_groups
        get_private_images if @options["get_private_images"]
        get_shared_images  if @options["get_shared_images"]
        get_public_images  if @options["get_public_images"]
        get_instances
        get_floating_ips
      end
      $aws_log.info("#{log_header}...Complete")

      filter_unused_disabled_flavors
      clean_up_extra_flavor_keys

      @data
    end

    private

    def security_groups
      @security_groups ||= @connection.security_groups
    end

    def get_flavors
      require 'Amazon/MiqEc2InstanceTypes'
      process_collection(MiqEc2InstanceTypes.all, :flavors) { |flavor| parse_flavor(flavor) }
    end

    def get_availability_zones
      azs = @connection.availability_zones
      process_collection(azs, :availability_zones) { |az| parse_availability_zone(az) }
    end

    def get_key_pairs
      kps = @connection.key_pairs
      process_collection(kps, :key_pairs) { |kp| parse_key_pair(kp) }
    end

    def get_cloud_networks
      vpcs = @connection.vpcs
      process_collection(vpcs, :cloud_networks) { |vpc| parse_cloud_network(vpc) }
    end

    def get_cloud_subnets(vpc)
      subnets = vpc.subnets
      process_collection(subnets, :cloud_subnets) { |s| parse_cloud_subnet(s) }
    end

    def get_security_groups
      process_collection(security_groups, :security_groups) { |sg| parse_security_group(sg) }
      get_firewall_rules
    end

    def get_firewall_rules
      security_groups.each do |sg|
        new_sg = @data_index.fetch_path(:security_groups, sg.id)
        new_sg[:firewall_rules] = get_inbound_firewall_rules(sg) + get_outbound_firewall_rules(sg)
      end
    end

    def get_inbound_firewall_rules(sg)
      sg.ip_permissions_list.collect { |perm| parse_firewall_rule(perm, "inbound") }.flatten
    end

    def get_outbound_firewall_rules(sg)
      sg.ip_permissions_list_egress.collect { |perm| parse_firewall_rule(perm, "outbound") }.flatten
    end

    def get_private_images
      get_images(@connection.images.with_owner(:self))
    end

    def get_shared_images
      get_images(@connection.images.executable_by(:self))
    end

    def get_public_images
      get_images(@connection.images.executable_by(:all), true)
    end

    def get_images(image_collection, is_public = false)
      images = image_collection.filter("image-type", "machine")
      process_collection(images, :vms) { |image| parse_image(image, is_public) }
    end

    def get_instances
      instances = @connection.instances
      process_collection(instances, :vms) { |instance| parse_instance(instance) }
    end

    def get_floating_ips
      ips = @connection.elastic_ips
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
        :type                     => "FlavorAmazon",
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
        :block_storage_based_only => flavor[:instance_store_volumes] == :ebs_only,

        # Extra keys
        :disk_size            => flavor[:instance_store_size].to_i,
        :disk_count           => flavor[:instance_store_volumes].to_i
      }

      return uid, new_result
    end

    def parse_availability_zone(az)
      name = uid = az.name

      # power_state = (az.state == :available) ? "on" : "off",

      new_result = {
        :type    => "AvailabilityZoneAmazon",
        :ems_ref => uid,
        :name    => name,
      }

      return uid, new_result
    end

    def self.key_pair_type
      'AuthKeyPairAmazon'
    end

    def parse_cloud_network(vpc)
      uid    = vpc.id

      name   = get_name_from_tags(vpc)
      name ||= uid

      status  = (vpc.state == :available) ? "active" : "inactive"

      get_cloud_subnets(vpc)
      cloud_subnets = vpc.subnets.collect { |s| @data_index.fetch_path(:cloud_subnets, s.id) }

      new_result = {
        :ems_ref => uid,
        :name    => name,
        :cidr    => vpc.cidr_block,
        :status  => status,
        :enabled => true,

        :cloud_subnets => cloud_subnets,
      }

      return uid, new_result
    end

    def parse_cloud_subnet(subnet)
      uid    = subnet.id

      name   = get_name_from_tags(subnet)
      name ||= uid

      new_result = {
        :ems_ref => uid,
        :name    => name,
        :cidr    => subnet.cidr_block,
        :status  => subnet.state.try(:to_s),

        :availability_zone => @data_index.fetch_path(:availability_zones, subnet.availability_zone_name)
      }

      return uid, new_result
    end

    def self.security_group_type
      'SecurityGroupAmazon'
    end

    def parse_security_group(sg)
      uid, new_result = super

      new_result[:cloud_network] = @data_index.fetch_path(:cloud_networks, sg.vpc_id)

      return uid, new_result
    end

    # TODO: Should ICMP protocol values have their own 2 columns, or
    #   should they override port and end_port like the Amazon API.
    def parse_firewall_rule(perm, direction)
      ret = []

      common = {
        :direction      => direction,
        :host_protocol  => perm[:ip_protocol].to_s.upcase,
        :port           => perm[:from_port],
        :end_port       => perm[:to_port],
      }

      perm[:groups].each do |g|
        new_result = common.dup
        new_result[:source_security_group] = @data_index.fetch_path(:security_groups, g[:group_id])
        ret << new_result
      end
      perm[:ip_ranges].each do |r|
        new_result = common.dup
        new_result[:source_ip_range] = r[:cidr_ip]
        ret << new_result
      end

      ret
    end

    def parse_image(image, is_public)
      uid      = image.id
      location = image.location
      guest_os = (image.platform == "windows") ? "windows" : "linux"

      name     = get_name_from_tags(image)
      name   ||= image.name
      name   ||= $1 if location =~ /^(.+?)(\.(image|img))?\.manifest\.xml$/
      name   ||= uid

      new_result = {
        :type            => "TemplateAmazon",
        :uid_ems         => uid,
        :ems_ref         => uid,
        :name            => name,
        :location        => location,
        :vendor          => "amazon",
        :raw_power_state => "never",
        :template        => true,
        # the is_public flag here avoids having to make an additional API call
        # per image, since we already know whether it's a public image
        :publicly_available => is_public,

        :hardware    => {
          :guest_os            => guest_os,
          :bitness             => ARCHITECTURE_TO_BITNESS[image.architecture],
          :virtualization_type => image.virtualization_type,
          :root_device_type    => image.root_device_type,
        },
      }

      return uid, new_result
    end

    def parse_instance(instance)
      status = instance.status
      return if @options["ignore_terminated_instances"] && status == :terminated

      uid    = instance.id
      name   = get_name_from_tags(instance)
      name ||= uid

      flavor_uid = instance.instance_type
      @known_flavors << flavor_uid
      flavor = @data_index.fetch_path(:flavors, flavor_uid)

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
        :type            => "VmAmazon",
        :uid_ems         => uid,
        :ems_ref         => uid,
        :name            => name,
        :vendor          => "amazon",
        :raw_power_state => status.to_s,

        :hardware    => {
          :bitness             => ARCHITECTURE_TO_BITNESS[instance.architecture],
          :virtualization_type => virtualization_type,
          :root_device_type    => root_device_type,
          :numvcpus            => flavor[:cpus],
          :cores_per_socket    => 1,
          :logical_cpus        => flavor[:cpus],
          :memory_cpu          => flavor[:memory] / (1024 * 1024), # memory_cpu is in megabytes
          :disk_capacity       => flavor[:disk_size],
          :disks               => [], # Filled in later conditionally on flavor
          :networks            => [], # Filled in later conditionally on what's available
        },

        :availability_zone => @data_index.fetch_path(:availability_zones, instance.availability_zone),
        :flavor            => flavor,
        :cloud_network     => @data_index.fetch_path(:cloud_networks, instance.vpc_id),
        :cloud_subnet      => @data_index.fetch_path(:cloud_subnets, instance.subnet_id),
        :key_pairs         => [@data_index.fetch_path(:key_pairs, instance.key_name)].compact,
        :security_groups   => instance.security_groups.to_a.collect { |sg| @data_index.fetch_path(:security_groups, sg.id) }.compact,
      }
      new_result[:location] = public_network[:hostname] if public_network[:hostname]
      new_result[:hardware][:networks] << private_network.merge(:description => "private") unless private_network.blank?
      new_result[:hardware][:networks] << public_network.merge(:description => "public")   unless public_network.blank?

      if parent_image
        new_result[:parent_vm] = parent_image
        new_result.store_path(:hardware, :guest_os, parent_image.fetch_path(:hardware, :guest_os))
      end

      if flavor[:disk_count] > 0
        disks = new_result[:hardware][:disks]
        single_disk_size = flavor[:disk_size] / flavor[:disk_count]
        flavor[:disk_count].times do |i|
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
        :type               => "FloatingIpAmazon",
        :ems_ref            => uid,
        :address            => address,
        :cloud_network_only => ip.vpc?,

        :vm => associated_vm
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

    def clean_up_extra_flavor_keys
      @data[:flavors].each do |f|
        f.delete(:disk_size)
        f.delete(:disk_count)
      end
    end

    def get_name_from_tags(resource)
      resource.tags.detect { |k, _| k.downcase == "name" }.try(:last)
    end

    def add_instance_disk(disks, size, name, location)
      super(disks, size, name, location, "amazon")
    end
  end
end
