require 'fog/google'

module ManageIQ::Providers
  module Google
    class NetworkManager::RefreshParser
      include Vmdb::Logging
      include ManageIQ::Providers::Google::RefreshHelperMethods

      def initialize(ems, options = nil)
        @ems               = ems
        @connection        = ems.connect
        @options           = options || {}
        @data              = {}
        @data_index        = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_cloud_networks
        get_security_groups
        get_network_ports
        get_floating_ips
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
        networks = @connection.networks.all
        process_collection(networks, :cloud_networks) { |network| parse_cloud_network(network) }
      end

      def subnetworks
        unless @subnetworks
          @subnetworks = @connection.subnetworks.all
          # For a backwards compatibility, old GCE networks were created without subnet. It's not possible now, but
          # GCE haven't migrated to new format. We will create a fake subnet for each network without subnets.
          @subnetworks += @connection.networks.select{ |x| x.ipv4_range.present? }.map do |x|
            Fog::Compute::Google::Subnetwork.new(
              :name               => x.name,
              :gateway_address    => x.gateway_ipv4,
              :ip_cidr_range      => x.ipv4_range,
              :id                 => x.id,
              :network            => x.self_link,
              :self_link          => x.self_link,
              :description        => "Subnetwork placeholder for GCE legacy networks without subnetworks",
              :creation_timestamp => x.creation_timestamp,
              :kind               => x.kind)
          end
        end

        @subnetworks
      end

      def subnets_by_link(subnet)
        unless @subnets_by_link
          @subnets_by_link = subnetworks.each_with_object({}) { |x, subnets| subnets[x.self_link] = x }
        end

        # For legacy GCE networks without subnets, we also try a network link
        @subnets_by_link[subnet['subnetwork']] || @subnets_by_link[subnet['network']]
      end

      def subnets_by_network_link(network_link)
        unless @subnets_by_network_link
          @subnets_by_network_link = subnetworks.each_with_object({}) { |x, subnets| (subnets[x.network] ||= [] ) << x }
        end

        @subnets_by_network_link[network_link]
      end

      def network_ports
        unless @network_ports
          @network_ports = []
          @connection.servers.all.each do |instance|
            @network_ports += instance.network_interfaces.each { |i| i["device_id"] = instance.id }
          end
        end
        @network_ports
      end

      def floating_ips
        floating_ips = []
        network_ports.select { |x| x['accessConfigs'] }.each do |network_port|
          floating_ips += network_port['accessConfigs'].map do |x|
            {:fixed_ip => network_port['networkIP'], :external_ip => x['natIP']}
          end
        end

        floating_ips
      end

      def get_cloud_subnets(subnets)
        process_collection(subnets, :cloud_subnets) { |s| parse_cloud_subnet(s) }
      end

      def get_security_groups
        networks = @data[:cloud_networks]
        firewalls = @connection.firewalls.all

        process_collection(networks, :security_groups) do |network|
          sg_firewalls = firewalls.select { |fw| parse_uid_from_url(fw.network) == network[:name] }
          parse_security_group(network, sg_firewalls)
        end
      end

      def get_floating_ips
        # Fetch non assigned static floating IPs
        ips = @connection.addresses.select { |x| x.status != "IN_USE" }
        process_collection(ips, :floating_ips) { |ip| parse_floating_ip(ip) }

        # Fetch assigned floating IPs
        process_collection(floating_ips, :floating_ips) { |ip| parse_floating_ip_inferred_from_instance(ip) }
      end

      def get_network_ports
        process_collection(network_ports, :network_ports) { |n| parse_network_port(n) }
      end

      def parse_cloud_network(network)
        uid = network.id

        subnets = subnets_by_network_link(network.self_link) || []
        get_cloud_subnets(subnets)
        cloud_subnets = subnets.collect { |s| @data_index.fetch_path(:cloud_subnets, s.id) }

        new_result = {
          :ems_ref => uid,
          :type    => self.class.cloud_network_type,
          :name    => network.name,
          :cidr    => network.ipv4_range,
          :status  => "active",
          :enabled => true,
          :cloud_subnets => cloud_subnets,
        }

        return uid, new_result
      end

      def parse_cloud_subnet(subnet)
        uid    = subnet.id

        name   = subnet.name
        name ||= uid

        new_result = {
          :type              => self.class.cloud_subnet_type,
          :ems_ref           => uid,
          :name              => name,
          :cidr              => subnet.ip_cidr_range,
          :gateway           => subnet.gateway_address,
        }

        return uid, new_result
      end

      def parse_security_group(network, firewalls)
        uid            = network[:name]
        firewall_rules = firewalls.collect { |fw| parse_firewall_rules(fw) }.flatten

        new_result = {
          :type           => self.class.security_group_type,
          :ems_ref        => uid,
          :name           => uid,
          :cloud_network  => network,
          :firewall_rules => firewall_rules,
        }

        return uid, new_result
      end

      def parse_firewall_rules(fw)
        ret = []

        name            = fw.name
        source_ip_range = fw.source_ranges.nil? ? "0.0.0.0/0" : fw.source_ranges.first

        fw.allowed.each do |fw_allowed|
          protocol      = fw_allowed["IPProtocol"].upcase
          allowed_ports = fw_allowed["ports"].to_a.first

          unless allowed_ports.nil?
            from_port, to_port = allowed_ports.split("-", 2)
          else
            # The ICMP protocol doesn't have ports so set to -1
            from_port = to_port = -1
          end

          new_result = {
            :name            => name,
            :direction       => "inbound",
            :host_protocol   => protocol,
            :port            => from_port,
            :end_port        => to_port,
            :source_ip_range => source_ip_range
          }

          ret << new_result
        end

        ret
      end

      def parse_floating_ip(ip)
        # this parser tracks only non used floating ips
        address = uid = ip.address

        new_result = {
          :type               => self.class.floating_ip_type,
          :ems_ref            => uid,
          :address            => address,
          :fixed_ip_address   => nil,
          :network_port       => nil,
          :vm                 => nil
        }

        return uid, new_result
      end

      def parse_floating_ip_inferred_from_instance(ip)
        address = uid = ip[:external_ip]

        new_result = {
          :type               => self.class.floating_ip_type,
          :ems_ref            => uid,
          :address            => address,
          :fixed_ip_address   => ip[:fixed_ip],
          :network_port       => @data_index.fetch_path(:network_ports, ip[:fixed_ip]),
          :vm                 => @data_index.fetch_path(:network_ports, ip[:fixed_ip], :device)
        }

        return uid, new_result
      end

      def parse_cloud_subnet_network_port(cloud_subnet_network_port, subnet_id)
        {
          :address      => cloud_subnet_network_port['networkIP'],
          :cloud_subnet => @data_index.fetch_path(:cloud_subnets, subnet_id)
        }
      end

      def parse_network_port(network_port)
        uid                        = network_port['networkIP']
        cloud_subnet_network_ports = [
          parse_cloud_subnet_network_port(network_port, subnets_by_link(network_port).try(:id))]
        device                     = parent_manager_fetch_path(:vms, network_port["device_id"])
        security_groups            = [
          @data_index.fetch_path(:security_groups, parse_uid_from_url(network_port['network']))]

        new_result = {
          :type                       => self.class.network_port_type,
          :name                       => network_port["name"],
          :ems_ref                    => uid,
          :status                     => nil,
          :mac_address                => nil,
          :device_ref                 => network_port["device_id"],
          :device                     => device,
          :cloud_subnet_network_ports => cloud_subnet_network_ports,
          :security_groups            => security_groups,
        }
        return uid, new_result
      end

      class << self
        def security_group_type
          ManageIQ::Providers::Google::NetworkManager::SecurityGroup.name
        end

        def network_router_type
          ManageIQ::Providers::Google::NetworkManager::NetworkRouter.name
        end

        def cloud_network_type
          ManageIQ::Providers::Google::NetworkManager::CloudNetwork.name
        end

        def cloud_subnet_type
          ManageIQ::Providers::Google::NetworkManager::CloudSubnet.name
        end

        def floating_ip_type
          ManageIQ::Providers::Google::NetworkManager::FloatingIp.name
        end

        def network_port_type
          ManageIQ::Providers::Google::NetworkManager::NetworkPort.name
        end
      end
    end
  end
end
