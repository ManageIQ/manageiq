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
            fetch_server_groups(feed, domain)

            # add the server groups to the domain
            parsed_domain[:middleware_server_groups] = @data[:middleware_server_groups]
            @data[:middleware_domains] << parsed_domain
            @data_index.store_path(:middleware_domains, :by_ems_ref, parsed_domain[:ems_ref], parsed_domain)

            # now it's safe to fetch the domain servers (it assumes the server groups to be already fetched)
            fetch_domain_servers(domain)
          end
        end
      end

      def fetch_server_groups(feed, domain)
        @ems.server_groups(feed, domain).each do |group|
          parsed_group = parse_middleware_server_group(group)
          @data[:middleware_server_groups] << parsed_group
          @data_index.store_path(:middleware_server_groups, :by_name, parsed_group[:name], parsed_group)
        end
      end

      def fetch_domain_servers(domain)
        @ems.child_resources(domain.path).each do |child|
          next unless child.type_path.end_with?(hawk_escape_id('Domain WildFly Server'))
          @eaps << child

          server_config = @ems.inventory_client.get_config_data_for_resource child.path
          child.properties.merge! server_config['value'] unless server_config['value'].nil?

          server_name = parse_domain_server_name(child.id)
          server = parse_middleware_server(child, true, server_name)

          # Add the association to server group. The information about what server is in which server group is under
          # the server-config resource's configuration
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
        @data[:middleware_messagings] = []
        @eaps.map do |eap|
          @ems.child_resources(eap.path, true).map do |child|
            next unless child.type_path.end_with?('Deployment', 'Datasource', 'JMS%20Topic', 'JMS%20Queue')
            server = @data_index.fetch_path(:middleware_servers, :by_ems_ref, eap.path)
            process_server_entity(server, child)
          end
        end
      end

      def fetch_availability
        resources_by_metric_id = {}
        @data[:middleware_deployments].each do |deployment|
          path = ::Hawkular::Inventory::CanonicalPath.parse(deployment[:ems_ref])
          # for subdeployments use it's parent deployment availability.
          path = path.up if path.resource_ids.last.include? CGI.escape('/subdeployment=')
          metric_id = @ems.build_availability_metric_id(
            URI.unescape(path.feed_id),
            URI.unescape(path.resource_ids.last),
            'Deployment Status~Deployment Status'
          )
          resources_by_metric_id[metric_id] = [] unless resources_by_metric_id.key? metric_id
          resources_by_metric_id[metric_id] << deployment
        end
        unless resources_by_metric_id.empty?
          availabilities = @ems.metrics_client.avail.raw_data(resources_by_metric_id.keys,
                                                              :limit => 1, :order => 'DESC')
          parse_availability availabilities, resources_by_metric_id
        end
      end

      def process_entity_with_config(server, entity, continuation)
        entity_id = hawk_escape_id entity.id
        server_path = ::Hawkular::Inventory::CanonicalPath.parse(server[:ems_ref])
        resource_ids = server_path.resource_ids << entity_id
        resource_path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id      => server_path.feed_id,
                                                                 :resource_ids => resource_ids)
        config = @ems.inventory_client.get_config_data_for_resource(resource_path.to_s)
        send(continuation, server, entity, config)
      end

      def process_server_entity(server, entity)
        if entity.type_path.end_with?('Deployment')
          @data[:middleware_deployments] << parse_deployment(server, entity)
        elsif entity.type_path.end_with?('Datasource')
          @data[:middleware_datasources] << process_entity_with_config(server, entity, :parse_datasource)
        else
          @data[:middleware_messagings] << process_entity_with_config(server, entity, :parse_messaging)
        end
      end

      def process_availability(availability = nil)
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

      def parse_availability(availabilities, resources_by_metric_id)
        processed_availabilities_ids = availabilities.map do |availability|
          availability_status = process_availability(availability['data'].first)
          resources_by_metric_id[availability['id']].each do |resource|
            resource[:status] = availability_status
          end
          availability['id']
        end
        (resources_by_metric_id.keys - processed_availabilities_ids).each do |metric_id|
          availability_status = process_availability
          resources_by_metric_id[metric_id].each do |resource|
            resource[:status] = availability_status
          end
        end
        resources_by_metric_id
      end

      def parse_deployment(server, deployment)
        specific = {
          :name              => parse_deployment_name(deployment.id),
          :middleware_server => server,
        }
        parse_base_item(deployment).merge(specific)
      end

      def parse_messaging(server, messaging, config)
        specific = {
          :name              => messaging.name,
          :middleware_server => server,
          :messaging_type    => messaging.to_h['type']['name']
        }
        if !config.empty? && !config['value'].empty? && config['value'].respond_to?(:except)
          specific[:properties] = config['value'].except('Username', 'Password')
        end
        parse_base_item(messaging).merge(specific)
      end

      def parse_datasource(server, datasource, config)
        specific = {
          :name              => datasource.name,
          :middleware_server => server,
        }
        if !config.empty? && !config['value'].empty? && config['value'].respond_to?(:except)
          specific[:properties] = config['value'].except('Username', 'Password')
        end
        parse_base_item(datasource).merge(specific)
      end

      def parse_middleware_domain(domain)
        specific = {
          :name      => domain.properties['Name'],
          :type_path => domain.type_path,
        }
        parse_base_item(domain).merge(specific)
      end

      def parse_middleware_server_group(group)
        specific = {
          :name      => parse_server_group_name(group.name),
          :type_path => group.type_path,
          :profile   => group.properties['Profile'],
        }
        parse_base_item(group).merge(specific)
      end

      def parse_middleware_server(eap, domain = false, name = nil)
        not_started = domain && eap.properties['Server State'] == 'STOPPED'

        hostname, product = ['Hostname', 'Product Name'].map do |x|
          not_started && eap.properties[x].nil? ? _('not yet available') : eap.properties[x]
        end

        specific = {
          :name      => name || parse_standalone_server_name(eap.id),
          :type_path => eap.type_path,
          :hostname  => hostname,
          :product   => product,
        }
        parse_base_item(eap).merge(specific)
      end

      private

      def parse_base_item(item)
        data = {
          :ems_ref  => item.path,
          :nativeid => item.id,
        }
        [:properties, :feed].each do |field|
          if item.respond_to? field
            data.merge!(field => item.send(field))
          end
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

      def parse_standalone_server_name(name)
        name.sub(/~~$/, '').sub(/^.*?~/, '')
      end
    end
  end
end
