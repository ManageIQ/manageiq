module ManageIQ::Providers
  module Hawkular
    class MiddlewareManager::RefreshParser
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
        @data[:middleware_servers] = get_middleware_servers
        fetch_server_entities
        @data
      end

      def get_middleware_servers
        @data[:middleware_servers] = []
        @ems.feeds.map do |feed|
          @ems.eaps(feed).map do |eap|
            @eaps << eap
            server = parse_middleware_server(eap)
            @data[:middleware_servers] << server
            @data_index.store_path(:middleware_servers, :by_nativeid, server[:nativeid], server)
          end
        end.flatten
      end

      def fetch_server_entities
        @data[:middleware_deployments] = []
        @data[:middleware_datasources] = []
        @eaps.map do |eap|
          @ems.child_resources(eap).map do |child|
            next unless child.type_path.end_with?('Deployment', 'Datasource')
            server = @data_index.fetch_path(:middleware_servers, :by_nativeid, eap.id)
            process_server_entity(server, child)
          end
        end
      end

      def process_datasource(server, datasource)
        config = @ems.get_config_data_for_resource([server[:nativeid], datasource.id], server[:feed])
        parse_datasource(server, datasource, config)
      end

      def process_server_entity(server, entity)
        if entity.type_path.end_with?('Deployment')
          @data[:middleware_deployments] << parse_deployment(server, entity)
        else
          @data[:middleware_datasources] << process_datasource(server, entity)
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
        unless config.empty? || config['value'].empty?
          data[:properties] = config['value'].select { |k, _| k != 'Username' && k != 'Password' }
        end
        data
      end

      def parse_deployment_name(name)
        name.sub(/^.*deployment=/, '')
      end

      def parse_middleware_server(eap)
        {
          :feed       => eap.feed,
          :ems_ref    => eap.path,
          :nativeid   => eap.id,
          :name       => parse_name(eap.id),
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
