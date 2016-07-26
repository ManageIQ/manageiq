module ManageIQ::Providers
  module Hawkular
    class MiddlewareManager::RefreshParser
      include ::HawkularUtilsMixin

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, _options = nil)
        @ems = ems
        @eaps = []
        @data = {}
        @data_index = {}
      end

      def ems_inv_to_hashes
        # the order of the method calls is important here, because they make use of @eaps and @data_index
        fetch_middleware_servers
        fetch_domains_with_servers
        fetch_server_entities
        fetch_availability
        @data
      end

      def fetch_middleware_servers
        @data[:middleware_servers] = []
        @ems.feeds.each do |feed|
          @ems.eaps(feed).each do |eap|
            @eaps << eap
            server = parse_middleware_server(eap)

            machine_id = @ems.machine_id(eap.feed)
            host_instance = find_host_by_bios_uuid(machine_id) ||
                            find_host_by_bios_uuid(alternate_machine_id(machine_id))

            if host_instance
              server[:lives_on_id] = host_instance.id
              server[:lives_on_type] = host_instance.type
            end

            @data[:middleware_servers] << server
            @data_index.store_path(:middleware_servers, :by_ems_ref, server[:ems_ref], server)
          end
        end
      end

      def fetch_domains_with_servers
        @data[:middleware_domains] = []
        @data[:middleware_server_groups] = []
        @ems.feeds.each do |feed|
          @ems.domains(feed).each do |domain|
            parsed_domain = parse_middleware_domain(domain)
            @data[:middleware_domains] << parsed_domain
            @data_index.store_path(:middleware_domains, :by_ems_ref, parsed_domain[:ems_ref], parsed_domain)

            fetch_server_groups(feed, domain, parsed_domain)
            fetch_domain_servers(domain)
          end
        end
      end

      def fetch_server_groups(feed, domain, parsed_domain)
        @ems.server_groups(feed, domain).each do |group|
          parsed_group = parse_middleware_server_group(parsed_domain, group)
          @data[:middleware_server_groups] << parsed_group
          @data_index.store_path(:middleware_server_groups, :by_name, parsed_group[:name], parsed_group)
        end
      end

      def fetch_domain_servers(domain)
        @ems.child_resources(domain.path).each do |child|
          next unless child.type_path.end_with?(hawk_escape_id('Domain WildFly Server'))
          @eaps << child

          server_name = parse_domain_server_name(child.id)
          server = parse_middleware_server(child, server_name)

          # add the association to server group (it's well hidden in the inventory)
          config_path = child.path.to_s.sub(/%2Fserver%3D/, '%2Fserver-config%3D')
          config = @ems.inventory_client.get_config_data_for_resource(config_path)
          server_group_name = config['value']['Server Group']
          server_group = @data_index.fetch_path(:middleware_server_groups, :by_name, server_group_name)
          server[:middleware_server_group] = server_group

          @data[:middleware_servers] << server
          @data_index.store_path(:middleware_servers, :by_ems_ref, server[:ems_ref], server)
        end
      end

      def alternate_machine_id(machine_id)
        return if machine_id.nil?
        # See the BZ #1294461 [1] for a more complete background.
        # Here, we'll try to adjust the machine ID to the format from that bug. We expect to get a string like
        # this: 2f68d133a4bc4c4bb19ecb47d344746c . For such string, we should return
        # this: 33d1682f-bca4-4b4c-b19e-cb47d344746c .The actual BIOS UUID is probably returned in upcase, but other
        # providers store it in downcase, so, we let the upcase/downcase logic to other methods with more
        # business knowledge.
        # 1 - https://bugzilla.redhat.com/show_bug.cgi?id=1294461
        alternate = []
        alternate << swap_part(machine_id[0, 8])
        alternate << swap_part(machine_id[8, 4])
        alternate << swap_part(machine_id[12, 4])
        alternate << machine_id[16, 4]
        alternate << machine_id[20, 12]
        alternate.join('-')
      end

      def swap_part(part)
        # here, we receive parts of an UUID, split into an array with 2 chars each element, and reverse the invidual
        # elements, joining and reversing the final outcome
        # for instance:
        # 2f68d133 -> ["2f", "68", "d1", "33"] -> ["f2", "86", "1d", "33"] -> f2861d33 -> 33d1682f
        part.scan(/../).collect(&:reverse).join.reverse
      end

      def find_host_by_bios_uuid(machine_id)
        return if machine_id.nil?
        identity_system = machine_id.downcase
        Vm.find_by(:uid_ems => identity_system,
                   :type    => uuid_provider_types) if identity_system
      end

      def uuid_provider_types
        # after the PoC, we might want to test/support these extra providers:
        # ManageIQ::Providers::Openstack::CloudManager::Vm
        # ManageIQ::Providers::Vmware::InfraManager::Vm
        'ManageIQ::Providers::Redhat::InfraManager::Vm'
      end

      def fetch_server_entities
        @data[:middleware_deployments] = []
        @data[:middleware_datasources] = []
        @eaps.map do |eap|
          @ems.child_resources(eap.path).map do |child|
            next unless child.type_path.end_with?('Deployment', 'Datasource')
            server = @data_index.fetch_path(:middleware_servers, :by_ems_ref, eap.path)
            process_server_entity(server, child)
          end
        end
      end

      def fetch_availability
        metric_ids = {}
        @data[:middleware_deployments].each do |deployment|
          metric_id = @ems.build_metric_id('A', deployment, 'Deployment Status~Deployment Status')
          metric_ids[metric_id] = deployment
        end
        availabilities = @ems.metrics_client.avail.raw_data(metric_ids.keys, :limit => 1, :order => 'DESC')
        availabilities.each do |availability|
          metric_ids[availability['id']][:status] = process_availability(availability['data'].first)
        end
      end

      def process_datasource(server, datasource)
        wildfly_res_id = hawk_escape_id server[:nativeid]
        datasource_res_id = hawk_escape_id datasource.id
        resource_path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id      => server[:feed],
                                                                 :resource_ids => [wildfly_res_id, datasource_res_id])
        config = @ems.inventory_client.get_config_data_for_resource(resource_path.to_s)
        parse_datasource(server, datasource, config)
      end

      def process_server_entity(server, entity)
        if entity.type_path.end_with?('Deployment')
          @data[:middleware_deployments] << parse_deployment(server, entity)
        else
          @data[:middleware_datasources] << process_datasource(server, entity)
        end
      end

      def process_availability(availability)
        case
        when availability.blank?, availability['value'].casecmp('unknown').zero?
          'Unknown'
        when availability['value'].casecmp('up').zero?
          'Enabled'
        when availability['value'].casecmp('down').zero?
          'Disabled'
        else
          'Unknown'
        end
      end

      def parse_deployment(server, deployment)
        {
          :name              => parse_deployment_name(deployment.id),
          :middleware_server => server, # TODO: does that make sense? What is better?
          :nativeid          => deployment.id,
          :ems_ref           => deployment.path
        }
      end

      def parse_datasource(server, datasource, config)
        data = {
          :name              => datasource.name,
          :middleware_server => server,
          :nativeid          => datasource.id,
          :ems_ref           => datasource.path
        }
        if !config.empty? && !config['value'].empty? && config['value'].respond_to?(:except)
          data[:properties] = config['value'].except('Username', 'Password')
        end
        data
      end

      def parse_deployment_name(name)
        name.sub(/^.*deployment=/, '')
      end

      def parse_server_group_name(name)
        name.sub(/^Domain Server Group \[/, '').chomp(']')
      end

      def parse_domain_server_name(name)
        name.sub(%r{^.*\/server=}, '')
      end

      def parse_middleware_domain(domain)
        {
          :feed       => domain.feed,
          :ems_ref    => domain.path,
          :nativeid   => domain.id,
          :name       => domain.properties['Name'],
          :type_path  => domain.type_path,
          :properties => domain.properties
        }
      end

      def parse_middleware_server_group(domain, group)
        {
          :feed              => group.feed,
          :ems_ref           => group.path,
          :nativeid          => group.id,
          :middleware_domain => domain,
          :name              => parse_server_group_name(group.name),
          :type_path         => group.type_path,
          :profile           => group.properties['Profile'],
          :properties        => group.properties
        }
      end

      def parse_middleware_server(eap, name = nil)
        {
          :feed       => eap.feed,
          :ems_ref    => eap.path,
          :nativeid   => eap.id,
          :name       => name || parse_name(eap.id),
          :hostname   => eap.properties['Hostname'],
          :product    => eap.properties['Product Name'],
          :type_path  => eap.type_path,
          :properties => eap.properties
        }
      end

      def parse_name(name)
        name.sub(/~~$/, '').sub(/^.*?~/, '')
      end
    end
  end
end
