module ManageIQ::Providers
  module Hawkular
    class MiddlewareManager::RefreshParser
      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems = ems
        @eaps = []
        @data = {}
        @data_index = {}
      end

      def ems_inv_to_hashes
        @data[:middleware_servers] = get_middleware_servers
        get_deployments
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

      def get_deployments
        @data[:middleware_deployments] = []
        @eaps.map do |eap|
          @ems.children(eap).map do |child|
            next unless child.type_path.end_with? 'Deployment'
            server = @data_index.fetch_path(:middleware_servers, :nativeid, eap.id)
            @data[:middleware_deployments] << parse_deployment(server, child)
          end
        end
      end

      def parse_deployment(server, deployment)
        {
          :name => parse_deployment_name(deployment.id),
          :middleware_server => server,  # TODO does that make sense? What is better?
          :nativeid => deployment.id,
          :ems_ref => deployment.path
        }
      end

      def parse_deployment_name(name)
        tmp = name.dup
        tmp.sub!(/^.*deployment=/,'')
        tmp
      end

      def parse_middleware_server(eap)
        {
          :feed       => eap.feed,
          :ems_ref    => eap.path,
          :nativeid   => eap.id,
          :name       => parse_name(eap.id),
          :host       => eap.properties['Hostname'] || '',
          :product    => eap.properties['Product Name'] || '',
          :type_path  => eap.type_path,
          :properties => eap.properties
        }
      end


      def parse_name(name)

        tmp = name.dup
        tmp.sub!(/~~$/,'')
        tmp.sub!(/^.*?~/,'')
        tmp
      end
    end
  end
end
