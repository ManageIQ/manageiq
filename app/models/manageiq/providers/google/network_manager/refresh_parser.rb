require 'digest'
require 'fog/google'

module ManageIQ::Providers
  module Google
    class NetworkManager::RefreshParser
      include Vmdb::Logging
      include ManageIQ::Providers::Google::RefreshHelperMethods

      GCP_HEALTH_STATUS_MAP = {
        "HEALTHY"   => "InService",
        "UNHEALTHY" => "OutOfService"
      }.freeze

      def initialize(ems, options = nil)
        @ems               = ems
        @connection        = ems.connect
        @options           = options || {}
        @data              = {}
        @data_index        = {}

        # Simple mapping from target pool's self_link url to the created
        # target pool entity.
        @target_pool_index = {}

        # Another simple mapping from target pool's self_link url to the set of
        # lbs that point at it
        @target_pool_link_to_load_balancers = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_cloud_networks
        get_security_groups
        get_network_ports
        get_floating_ips
        get_load_balancers
        get_load_balancer_pools
        get_load_balancer_listeners
        get_load_balancer_health_checks

        _log.info("#{log_header}...Complete")

        @data
      end

      # Parses a port range returned by GCP from a string to a Range. Note that
      # GCP treats the empty port range "" to mean all ports; hence this method
      # returns 0..65535 when the input is the empty string.
      #
      # @param port_range [String] the port range (e.g. "" or "80-123" or "11")
      # @return [Range] a range representing the port range
      def self.parse_port_range(port_range)
        # Three forms:
        # "80"
        # "5000-5010"
        # "" (all ports)
        m = /\A(\d+)(?:-(\d+))?\Z/.match(port_range)
        return 0..65_535 unless m

        start = Integer(m[1])
        finish = m[2] ? Integer(m[2]) : start
        start..finish
      end

      # Parses a VM's self_link attribute to extract the project name, zone, and
      # instance name. Used when other services refer to a VM by its link.
      #
      # @param vm_link [String] the full url to the vm (e.g.
      #   "https://www.googleapis.com/compute/v1/projects/myproject/zones/us-central1-a/instances/foobar")
      # @return [Hash{Symbol => String}, nil] a hash containing extracted components
      #   for `:project`, `:zone`, and `:instance`, or nil if the link did not
      #   match.
      def self.parse_vm_link(vm_link)
        link_regexp = %r{\Ahttps://www\.googleapis\.com/compute/v1/projects/([^/]+)/zones/([^/]+)/instances/([^/]+)\Z}
        m = link_regexp.match(vm_link)
        return nil if m.nil?

        {
          :project  => m[1],
          :zone     => m[2],
          :instance => m[3]
        }
      end

      def self.parse_health_check_link(health_check_link)
        link_regexp = %r{\Ahttps://www\.googleapis\.com/compute/v1/projects/([^/]+)/global/httpHealthChecks/([^/]+)\Z}

        m = link_regexp.match(health_check_link)
        return nil if m.nil?

        {
          :project      => m[1],
          :health_check => m[2]
        }
      end

      private

      def get_health_check_from_link(link)
        parts = self.class.parse_health_check_link(link)
        unless parts
          _log.warn("Unable to parse health check link: #{link}")
          return nil
        end

        return nil unless @connection.project == parts[:project]
        get_health_check_cached(parts[:health_check])
      end

      def get_health_check_cached(health_check)
        @health_check_cache ||= {}

        return @health_check_cache.fetch_path(health_check) if @health_check_cache.has_key_path?(health_check)

        @health_check_cache.store_path(health_check, @connection.http_health_checks.get(health_check))
      rescue Fog::Errors::Error => err
        m = "Error during data collection for [#{@ems.name}] id: [#{@ems.id}] when querying link for health check: #{err}"
        _log.warn(m)
        _log.warn(err.backtrace.join("\n"))
        nil
      end

      # Lookup a VM in fog via its link to get the VM id (which is equivalent to
      # the ems_ref).
      #
      # @param link [String] the full url to the vm
      # @return [String, nil] the vm id, or nil if it could not be found
      def get_vm_id_from_link(link)
        parts = self.class.parse_vm_link(link)
        unless parts
          _log.warn("Unable to parse vm link: #{link}")
          return nil
        end

        # Ensure our connection is using the same project; if it's not we can't
        # do much
        return nil unless @connection.project == parts[:project]

        get_vm_id_cached(parts[:zone], parts[:instance])
      end

      # Look up a VM in fog via a given zone and instance for the current
      # project to get the VM id. Note this method caches matched values during
      # this instance's entire lifetime.
      #
      # @param zone [String] the zone of the vm
      # @param instance [String] the name of the vm
      # @return [String, nil] the vm id, or nil if it could not be found
      def get_vm_id_cached(zone, instance)
        @vm_cache ||= {}

        return @vm_cache.fetch_path(zone, instance) if @vm_cache.has_key_path?(zone, instance)

        begin
          @vm_cache.store_path(zone, instance, @connection.get_server(instance, zone)[:body]["id"])
        rescue Fog::Errors::Error => err
          m = "Error during data collection for [#{@ems.name}] id: [#{@ems.id}] when querying link for vm_id: #{err}"
          _log.warn(m)
          _log.warn(err.backtrace.join("\n"))
          nil
        end
      end

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
          @subnetworks += @connection.networks.select { |x| x.ipv4_range.present? }.map do |x|
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
          @subnets_by_network_link = subnetworks.each_with_object({}) { |x, subnets| (subnets[x.network] ||= []) << x }
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
        process_collection(subnets, :cloud_subnets, false) { |s| parse_cloud_subnet(s) }
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

      def get_load_balancers
        # GCE uses forwarding-rules rather than load-balancers
        forwarding_rules = @connection.forwarding_rules.all

        process_collection(forwarding_rules, :load_balancers) { |forwarding_rule| parse_load_balancer(forwarding_rule) }
      end

      def get_load_balancer_pools
        # Right now we only support network-based load-balancers, instead of the
        # more complicated HTTP/HTTPS load balancers.
        # TODO(jsselman): Add support for http/https proxies
        target_pools = @connection.target_pools.all

        process_collection(target_pools, :load_balancer_pools) { |target_pool| parse_load_balancer_pool(target_pool) }
        get_load_balancer_pool_members(target_pools)
      end

      def get_load_balancer_pool_members(target_pools)
        @data[:load_balancer_pool_members] = []

        target_pools.each do |tp|
          lb_pool_members = tp.instances.collect { |m| parse_load_balancer_pool_member(m) }
          lb_pool_members.each do |member|
            @data_index.store_path(:load_balancer_pool_members, member[:ems_ref], member)
            @data[:load_balancer_pool_members] << member
          end
          lb_pool = @data_index.fetch_path(:load_balancer_pools, tp.id)
          lb_pool[:load_balancer_pool_member_pools] = lb_pool_members.collect do |member|
            {:load_balancer_pool_member => member}
          end
        end
      end

      def get_load_balancer_listeners
        # There's no explicit listener concept in GCE, so again we reuse the
        # forwarding rule.
        forwarding_rules = @connection.forwarding_rules.all

        process_collection(forwarding_rules, :load_balancer_listeners) do |forwarding_rule|
          parse_load_balancer_listener(forwarding_rule)
        end
      end

      def get_load_balancer_health_checks
        target_pools = @connection.target_pools.all

        process_collection(target_pools, :load_balancer_health_checks) do |health_check|
          parse_load_balancer_health_check(health_check)
        end
      end

      def parse_load_balancer(forwarding_rule)
        uid = forwarding_rule.id

        new_result = {
          :type    => ManageIQ::Providers::Google::NetworkManager::LoadBalancer.name,
          :ems_ref => uid,
          :name    => forwarding_rule.name
        }

        return uid, new_result
      end

      def parse_load_balancer_pool(target_pool)
        uid = target_pool.id

        new_result = {
          :type    => ManageIQ::Providers::Google::NetworkManager::LoadBalancerPool.name,
          :ems_ref => uid,
          :name    => target_pool.name
        }

        @target_pool_index[target_pool.self_link] = new_result

        return uid, new_result
      end

      def parse_load_balancer_pool_member(member_link)
        vm_id = get_vm_id_from_link(member_link)
        {
          :type    => "ManageIQ::Providers::Google::NetworkManager::LoadBalancerPoolMember",
          :ems_ref => Digest::MD5.base64digest(member_link),
          :vm      => (parent_manager_fetch_path(:vms, vm_id) if vm_id)
        }
      end

      def parse_load_balancer_listener(forwarding_rule)
        uid = forwarding_rule.id

        # Only TCP/UDP/SCTP forwarding rules have ports
        has_ports = %w(TCP UDP SCTP).include?(forwarding_rule.ip_protocol)

        new_result = {
          :type                         => ManageIQ::Providers::Google::NetworkManager::LoadBalancerListener.name,
          :name                         => forwarding_rule.name,
          :ems_ref                      => uid,
          :load_balancer_protocol       => forwarding_rule.ip_protocol,
          :instance_protocol            => forwarding_rule.ip_protocol,
          :load_balancer_port_range     => (self.class.parse_port_range(forwarding_rule.port_range) if has_ports),
          :instance_port_range          => (self.class.parse_port_range(forwarding_rule.port_range) if has_ports),
          :load_balancer                => @data_index.fetch_path(:load_balancers, forwarding_rule.id),
          :load_balancer_listener_pools => [
            {:load_balancer_pool        => @target_pool_index[forwarding_rule.target]}
          ]
        }

        if forwarding_rule.target
          # Make sure we link the target link back to this instance for future
          # back-references
          @target_pool_link_to_load_balancers[forwarding_rule.target] ||= Set.new
          @target_pool_link_to_load_balancers[forwarding_rule.target].add(new_result[:load_balancer])
        end

        return uid, new_result
      end

      def parse_load_balancer_health_check(target_pool)
        # Target pools aren't required to have health checks
        return if target_pool.health_checks.nil? || target_pool.health_checks.empty?

        # For some reason a target pool has a list of health checks, but the API
        # won't accept more than one. Ignore the rest
        _log.warn("Expected one health check on target pool but found many! Ignoring all but the first.") \
          if target_pool.health_checks.size > 1

        health_check = get_health_check_from_link(target_pool.health_checks.first)

        @target_pool_link_to_load_balancers[target_pool.self_link].collect do |load_balancer|
          load_balancer_listener = @data_index.fetch_path(:load_balancer_listeners, load_balancer[:ems_ref])
          return nil if load_balancer_listener.nil?

          uid = "#{load_balancer[:ems_ref]}_#{target_pool.id}_#{health_check.id}"
          new_result = {
            :name                               => health_check.name,
            :ems_ref                            => uid,
            :type                               => ManageIQ::Providers::Google::NetworkManager::LoadBalancerHealthCheck.name,
            :protocol                           => "HTTP",
            :port                               => health_check.port,
            :url_path                           => health_check.request_path,
            :interval                           => health_check.check_interval_sec,
            :timeout                            => health_check.timeout_sec,
            :unhealthy_threshold                => health_check.unhealthy_threshold,
            :healthy_threshold                  => health_check.healthy_threshold,
            :load_balancer                      => load_balancer,
            :load_balancer_listener             => load_balancer_listener,
            :load_balancer_health_check_members => parse_load_balancer_health_check_members(target_pool)
          }
          [uid, new_result]
        end
      end

      def parse_load_balancer_health_check_members(target_pool)
        # First attempt to get the health of the instance
        # Due to a bug in fog, there's no way to get the health of an individual
        # member. Instead we have to get the health of the entire target_pool,
        # which if it fails means we skip.
        # Issue here: https://github.com/fog/fog-google/issues/162
        target_pool.get_health.collect do |instance_link, instance_health|
          # attempt to look up the load balancer member
          member = @data_index.fetch_path(:load_balancer_pool_members, Digest::MD5.base64digest(instance_link))
          return nil unless member

          # Lookup our health state in the health status map; default to
          # "OutOfService" if we can't find a mapping.
          status = "OutOfService"
          unless instance_health.nil?
            gcp_status = instance_health[0]["healthState"]

            if GCP_HEALTH_STATUS_MAP.include?(gcp_status)
              status = GCP_HEALTH_STATUS_MAP[gcp_status]
            else
              _log.warn("Unable to find an explicit health status mapping for state: #{gcp_status} - defaulting to 'OutOfService'")
            end
          end

          {
            :load_balancer_pool_member => member,
            :status                    => status,
            :status_reason             => ""
          }
        end
      rescue Fog::Errors::Error => err
        _log.warn("Caught unexpected error when probing health for target pool #{target_pool.name}: #{err}")
        _log.warn(err.backtrace.join("\n"))
        return []
      end

      def parse_cloud_network(network)
        uid = network.id

        subnets = subnets_by_network_link(network.self_link) || []
        get_cloud_subnets(subnets)
        cloud_subnets = subnets.collect { |s| @data_index.fetch_path(:cloud_subnets, s.id) }

        new_result = {
          :ems_ref       => uid,
          :type          => self.class.cloud_network_type,
          :name          => network.name,
          :cidr          => network.ipv4_range,
          :status        => "active",
          :enabled       => true,
          :cloud_subnets => cloud_subnets,
        }

        return uid, new_result
      end

      def parse_cloud_subnet(subnet)
        uid    = subnet.id

        name   = subnet.name
        name ||= uid

        new_result = {
          :type    => self.class.cloud_subnet_type,
          :ems_ref => uid,
          :name    => name,
          :status  => "active",
          :cidr    => subnet.ip_cidr_range,
          :gateway => subnet.gateway_address,
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

          if allowed_ports.nil?
            # The ICMP protocol doesn't have ports so set to -1
            from_port = to_port = -1
          else
            from_port, to_port = allowed_ports.split("-", 2)
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
          :type             => self.class.floating_ip_type,
          :ems_ref          => uid,
          :address          => address,
          :fixed_ip_address => nil,
          :network_port     => nil,
          :vm               => nil
        }

        return uid, new_result
      end

      def parse_floating_ip_inferred_from_instance(ip)
        address = uid = ip[:external_ip]

        new_result = {
          :type             => self.class.floating_ip_type,
          :ems_ref          => uid,
          :address          => address,
          :fixed_ip_address => ip[:fixed_ip],
          :network_port     => @data_index.fetch_path(:network_ports, ip[:fixed_ip]),
          :vm               => @data_index.fetch_path(:network_ports, ip[:fixed_ip], :device)
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
