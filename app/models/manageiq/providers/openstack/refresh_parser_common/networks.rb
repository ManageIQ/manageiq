module ManageIQ::Providers
  module Openstack
    module RefreshParserCommon
      module Networks
        def security_groups
          @security_groups ||= @network_service.handled_list(:security_groups)
        end

        def networks
          @networks ||= @network_service.handled_list(:networks)
        end

        def network_ports
          @network_ports ||= @network_service.handled_list(:ports)
        end

        def network_routers
          @network_routers ||= @network_service.handled_list(:routers)
        end

        def floating_ips_neutron
          @network_service.handled_list(:floating_ips)
        end

        # maintained for legacy nova network support
        def floating_ips_nova
          @connection.handled_list(:addresses)
        end

        def get_networks
          return unless @network_service.name == :neutron

          process_collection(networks, :cloud_networks) { |n| parse_network(n) }
          get_subnets
        end

        def get_network_routers
          return unless @network_service.name == :neutron

          process_collection(network_routers, :network_routers) { |n| parse_network_router(n) }
        end

        def get_network_ports
          return unless @network_service.name == :neutron

          process_collection(network_ports, :network_ports) { |n| parse_network_port(n) }
        end

        def get_subnets
          return unless @network_service.name == :neutron
          @data[:cloud_subnets] = []

          networks.each do |n|
            new_net = @data_index.fetch_path(:cloud_networks, n.id)
            new_net[:cloud_subnets] = n.subnets.collect { |s| parse_subnet(s) }

            # Lets store also subnets into indexed data, so we can reference them elsewhere
            new_net[:cloud_subnets].each do |x|
              @data_index.store_path(:cloud_subnets, x[:ems_ref], x)
              @data[:cloud_subnets] << x
            end
          end
        end

        def get_floating_ips
          ips = send("floating_ips_#{@network_service.name}")
          process_collection(ips, :floating_ips) { |ip| parse_floating_ip(ip) }
        end

        def get_security_groups
          process_collection(security_groups, :security_groups) { |sg| parse_security_group(sg) }
          get_firewall_rules
        end

        def get_firewall_rules
          security_groups.each do |sg|
            new_sg = @data_index.fetch_path(:security_groups, sg.id)
            new_sg[:firewall_rules] = sg.security_group_rules.collect { |r| parse_firewall_rule(r) }
          end
        end

        def parse_security_group(sg)
          uid, security_group = super
          security_group[:cloud_tenant]        = @data_index.fetch_path(:cloud_tenants, sg.tenant_id)
          security_group[:orchestration_stack] = @data_index.fetch_path(:orchestration_stacks, @resource_to_stack[uid])
          return uid, security_group
        end

        # TODO: Should ICMP protocol values have their own 2 columns, or
        #   should they override port and end_port like the Amazon API.
        def parse_firewall_rule(rule)
          send("parse_firewall_rule_#{@network_service.name}", rule)
        end

        def parse_network(network)
          uid     = network.id
          status  = (network.status.to_s.downcase == "active") ? "active" : "inactive"

          network_type_suffix = network.router_external ? "::Public" : "::Private"

          new_result = {
            :type                      => self.class.cloud_network_type + network_type_suffix,
            :name                      => network.name,
            :ems_ref                   => uid,
            :shared                    => network.shared,
            :status                    => status,
            :enabled                   => network.admin_state_up,
            :external_facing           => network.router_external,
            :cloud_tenant              => @data_index.fetch_path(:cloud_tenants, network.tenant_id),
            :orchestration_stack       => @data_index.fetch_path(:orchestration_stacks, @resource_to_stack[uid]),
            :provider_physical_network => network.provider_physical_network,
            :provider_network_type     => network.provider_network_type,
            :provider_segmentation_id  => network.provider_segmentation_id,
            :vlan_transparent          => network.attributes["vlan_transparent"],
            # TODO(lsmola) expose attributes in FOG
            :maximum_transmission_unit => network.attributes["mtu"],
            :port_security_enabled     => network.attributes["port_security_enabled"],
          }
          return uid, new_result
        end

        def find_device_object(network_port, subnet_id)
          case network_port.device_owner
          when /^compute\:.*?$/
            # Owner is in format compute:<availability_zone> or compute:None
            return find_device_connected_to_network_port(network_port.device_id)
          when "network:router_gateway"
            # TODO(lsmola) the gateway here is public network, we model it directly now, that will probably change
          when "network:dhcp"
            # TODO(lsmola) we need to represent dhcp as object
          when "network:floatingip"
            # We don't need this association, floating ip has a direct link to subnet and network in it
          when "network:router_interface"
            network_router          = @data_index.fetch_path(:network_routers, network_port.device_id)
            subnet                  = @data_index.fetch_path(:cloud_subnets, subnet_id)
            subnet[:network_router] = network_router
          end
          # Returning nil for non VM port, we don't want to store those as ports
          nil
        end

        def parse_network_port(network_port)
          uid             = network_port.id
          # There can be multiple fixed_ips on the port, but only under one subnet
          subnet_id       = network_port.fixed_ips.try(:first).try(:[], "subnet_id")
          device          = find_device_object(network_port, subnet_id)
          security_groups = network_port.security_groups.blank? ? [] :network_port.security_groups.map do |x|
            @data_index.fetch_path(:security_groups, x)
          end

          new_result = {
            :type                              => self.class.network_port_type,
            :name                              => network_port.name,
            :ems_ref                           => uid,
            :status                            => network_port.status,
            :admin_state_up                    => network_port.admin_state_up,
            :cloud_subnet                      => @data_index.fetch_path(:cloud_subnets, subnet_id),
            :mac_address                       => network_port.attributes[:mac_address],
            :device_owner                      => network_port.device_owner,
            :device_ref                        => network_port.device_id,
            :device                            => device,
            :cloud_tenant                      => @data_index.fetch_path(:cloud_tenants, network_port.tenant_id),
            # TODO(lsmola) expose missing atttributes in FOG
            :binding_host_id                   => network_port.attributes["binding:host_id"],
            :binding_virtual_interface_type    => network_port.attributes["binding:vif_type"],
            :binding_virtual_interface_details => network_port.attributes["binding:vif_details"],
            :binding_virtual_nic_type          => network_port.attributes["binding:vnic_type"],
            :binding_profile                   => network_port.attributes["binding:profile"],
            :extra_dhcp_opts                   => network_port.attributes["extra_dhcp_opts"],
            :allowed_address_pairs             => network_port.attributes["allowed_address_pairs"],
            :fixed_ips                         => network_port.fixed_ips,
            :security_groups                   => security_groups,
          }
          return uid, new_result
        end

        def parse_network_router(network_router)
          uid        = network_router.id
          network_id = network_router.try(:external_gateway_info).try(:fetch_path, "network_id")
          new_result = {
            :type                  => self.class.network_router_type,
            :name                  => network_router.name,
            :ems_ref               => uid,
            :cloud_network         => @data_index.fetch_path(:cloud_networks, network_id),
            :admin_state_up        => network_router.admin_state_up,
            :cloud_tenant          => @data_index.fetch_path(:cloud_tenants, network_router.tenant_id),
            :status                => network_router.status,
            # TODO(lsmola) expose missing atttributes in FOG
            :external_gateway_info => network_router.external_gateway_info,
            :distributed           => network_router.attributes["distributed"],
            :routes                => network_router.attributes["routes"],
            :high_availability     => network_router.attributes["ha"],
          }
          return uid, new_result
        end

        def parse_subnet(subnet)
          {
            :type                           => self.class.cloud_subnet_type,
            :name                           => subnet.name,
            :ems_ref                        => subnet.id,
            :cidr                           => subnet.cidr,
            :network_protocol               => "ipv#{subnet.ip_version}",
            :gateway                        => subnet.gateway_ip,
            :dhcp_enabled                   => subnet.enable_dhcp,
            :cloud_tenant_id                => @data_index.fetch_path(:cloud_tenants, subnet.tenant_id),
            :dns_nameservers                => subnet.dns_nameservers,
            :ipv6_router_advertisement_mode => subnet.attributes["ipv6_ra_mode"],
            :ipv6_address_mode              => subnet.attributes["ipv6_address_mode"],
            :allocation_pools               => subnet.allocation_pools,
            :host_routes                    => subnet.host_routes,
            :ip_version                     => subnet.ip_version,
            :subnetpool_id                  => subnet.attributes["subnetpool_id"],
          }
        end

        def parse_firewall_rule_neutron(rule)
          direction = (rule.direction == "egress") ? "outbound" : "inbound"
          {
            :direction             => direction,
            :ems_ref               => rule.id.to_s,
            :host_protocol         => rule.protocol.to_s.upcase,
            :network_protocol      => rule.ethertype.to_s.upcase,
            :port                  => rule.port_range_min,
            :end_port              => rule.port_range_max,
            :source_security_group => rule.remote_group_id,
            :source_ip_range       => rule.remote_ip_prefix,
          }
        end

        def parse_firewall_rule_nova(rule)
          {
            :direction             => "inbound",
            :ems_ref               => rule.id.to_s,
            :host_protocol         => rule.ip_protocol.to_s.upcase,
            :port                  => rule.from_port,
            :end_port              => rule.to_port,
            :source_security_group => data_security_groups_by_name[rule.group["name"]],
            :source_ip_range       => rule.ip_range["cidr"],
          }
        end

        def parse_floating_ip(ip)
          send("parse_floating_ip_#{@network_service.name}", ip)
        end

        def parse_floating_ip_neutron(ip)
          uid     = ip.id
          address = ip.floating_ip_address

          associated_vm = find_vm_associated_with_floating_ip(address)

          new_result = {
            :type                 => self.class.floating_ip_type,
            :ems_ref              => uid,
            :address              => address,
            :fixed_ip_address     => ip.fixed_ip_address,
            :vm                   => associated_vm,
            :cloud_tenant         => @data_index.fetch_path(:cloud_tenants, ip.tenant_id),
            :cloud_network        => @data_index.fetch_path(:cloud_networks, ip.floating_network_id),
            :status               => ip.attributes['status'],
            :network_port_ems_ref => ip.port_id
          }

          return uid, new_result
        end

        # maintained for legacy nova network support
        def parse_floating_ip_nova(ip)
          uid     = ip.id
          address = ip.ip

          associated_vm = find_vm_associated_with_floating_ip(address)

          new_result = {
            :type    => self.class.floating_ip_type,
            :ems_ref => uid,
            :address => address,

            :vm      => associated_vm
          }

          return uid, new_result
        end

        def link_network_ports_associations
          return unless @network_service.name == :neutron
          # link network ports to floating ips
          return unless (floating_ips = @data.fetch_path(:floating_ips))
          floating_ips.each do |floating_ip|
            network_port_ems_ref = floating_ip.delete(:network_port_ems_ref)
            floating_ip[:network_port] = @data_index.fetch_path(:network_ports, network_port_ems_ref)
          end
        end

        #
        # Helper methods
        #

        def find_vm_associated_with_floating_ip(ip_address)
          # TODO(lsmola) delete the when we are not supporting nova network and grizzly
          # Old way of associating floating_ip, neutron uses network_port_association
          return unless @network_service.name == :nova
          @data[:vms].detect do |v|
            v.fetch_path(:hardware, :networks).to_miq_a.detect do |n|
              n[:description] == "public" && n[:ipaddress] == ip_address
            end
          end
        end

        def data_security_groups_by_name
          @data_security_groups_by_name ||= @data[:security_groups].index_by { |sg| sg[:name] }
        end
      end
    end
  end
end
