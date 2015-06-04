module EmsRefresh
  module Parsers
    module OpenstackCommon
      module Networks
        def security_groups
          @security_groups ||= @network_service.security_groups_for_accessible_tenants
        end

        def networks
          @networks ||= @network_service.networks_for_accessible_tenants
        end

        def floating_ips_neutron
          @network_service.floating_ips
        end

        # maintained for legacy nova network support
        def floating_ips_nova
          @network_service.addresses_for_accessible_tenants
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

        def get_floating_ips
          ips = send("floating_ips_#{@network_service_name}")
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
          send("parse_firewall_rule_#{@network_service_name}", rule)
        end

        def parse_network(network)
          uid     = network.id
          status  = (network.status.to_s.downcase == "active") ? "active" : "inactive"

          new_result = {
            :name                => network.name,
            :ems_ref             => uid,
            :shared              => network.shared,
            :status              => status,
            :enabled             => network.admin_state_up,
            :external_facing     => network.router_external,
            :cloud_tenant        => @data_index.fetch_path(:cloud_tenants, network.tenant_id),
            :orchestration_stack => @data_index.fetch_path(:orchestration_stacks, @resource_to_stack[uid])
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
          send("parse_floating_ip_#{@network_service_name}", ip)
        end

        def parse_floating_ip_neutron(ip)
          uid     = ip.id
          address = ip.floating_ip_address

          associated_vm = find_vm_associated_with_floating_ip(address)

          new_result = {
            :type         => "FloatingIpOpenstack",
            :ems_ref      => uid,
            :address      => address,

            :vm           => associated_vm,
            :cloud_tenant => @data_index.fetch_path(:cloud_tenants, ip.tenant_id)
          }

          return uid, new_result
        end

        # maintained for legacy nova network support
        def parse_floating_ip_nova(ip)
          uid     = ip.id
          address = ip.ip

          associated_vm = find_vm_associated_with_floating_ip(address)

          new_result = {
            :type    => "FloatingIpOpenstack",
            :ems_ref => uid,
            :address => address,

            :vm      => associated_vm
          }

          return uid, new_result
        end

        #
        # Helper methods
        #

        def find_vm_associated_with_floating_ip(ip_address)
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
