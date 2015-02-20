module EmsRefresh::Parsers
  module OpenstackMixin

    def networks
      @networks ||= @network_service.networks
    end

    def get_flavors
      flavors = @connection.flavors
      process_collection(flavors, :flavors) { |flavor| parse_flavor(flavor) }
    end

    def get_private_flavor(id)
      private_flavor = @connection.flavors.get(id)
      process_collection([private_flavor], :flavors) { |flavor| parse_flavor(flavor) }
    end

    def get_images
      images = @image_service.images_for_accessible_tenants
      process_collection(images, :vms) { |image| parse_image(image) }
    end

    def get_networks
      return unless @network_service_name == :neutron
      process_collection(networks, :cloud_networks) { |n| parse_network(n) }
      get_subnets
    end

    def get_subnets
      return unless @network_service_name == :neutron

      networks.each do |n|
        new_net = @data_index.fetch_path(:cloud_networks, n.id)
        new_net[:cloud_subnets] = n.subnets.collect { |s| parse_subnet(s) }
      end
    end

    def parse_flavor(flavor)
      uid = flavor.id

      new_result = {
        :type    => "FlavorOpenstack",
        :ems_ref => uid,
        :name    => flavor.name,
        :enabled => !flavor.disabled,
        :cpus    => flavor.vcpus,
        :memory  => flavor.ram.megabytes,

        # Extra keys
        :root_disk      => flavor.disk.to_i.gigabytes,
        :ephemeral_disk => flavor.ephemeral.to_i.gigabytes,
        :swap_disk      => flavor.swap.to_i.megabytes
      }

      return uid, new_result
    end

    def parse_image(image)
      uid = image.id

      parent_server_uid = parse_image_parent_id(image)

      new_result = {
        :type            => "TemplateOpenstack",
        :uid_ems         => uid,
        :ems_ref         => uid,
        :name            => image.name,
        :vendor          => "openstack",
        :raw_power_state => "never",
        :template        => true,
        :publicly_available => image.is_public
      }
      new_result[:parent_vm_uid] = parent_server_uid unless parent_server_uid.nil?
      new_result[:cloud_tenant]  = @data_index.fetch_path(:cloud_tenants, image.owner) if image.owner

      return uid, new_result
    end

    def parse_image_parent_id(image)
      image_parent = @image_service_name == :glance ? image.copy_from : image.server
      image_parent["id"] if image_parent
    end

    def parse_network(network)
      uid     = network.id
      status  = (network.status.to_s.downcase == "active") ? "active" : "inactive"

      new_result = {
        :name            => network.name,
        :ems_ref         => uid,
        :status          => status,
        :enabled         => network.admin_state_up,
        :external_facing => network.router_external,
        :cloud_tenant    => @data_index.fetch_path(:cloud_tenants, network.tenant_id)
      }
      return uid, new_result
    end

    def parse_subnet(subnet)
      {
        :name             => subnet.name,
        :ems_ref          => subnet.id,
        :cidr             => subnet.cidr,
        :network_protocol => "ipv#{subnet.ip_version}",
        :gateway          => subnet.gateway_ip,
        :dhcp_enabled     => subnet.enable_dhcp,
      }
    end

  end
end  
