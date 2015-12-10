module ManageIQ::Providers
  module Hawkular
    class MiddlewareManager::RefreshParser
      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @eaps = []
        @ems = ems
      end

      def ems_inv_to_hashes
        @data = {}
        @data[:middleware_servers] = get_middleware_servers
        @data[:middleware_deployments] = get_deployments
        @data
      end

      def get_middleware_servers
        @ems.feeds.map do |feed|
          @ems.eaps(feed).map do |eap|
            @eaps << eap
            parse_middleware_servers(eap)
          end
        end.flatten
      end

      def get_deployments
        ret = @eaps.map do |server|
          @ems.children(server).map do |child|
            next unless child.type_path.end_with? 'Deployment'
            parse_deployment(server, child)
          end
        end.flatten
        ret.delete(nil)
        ret
      end

      def parse_deployment(eap, deployment)
        {
          :name => parse_deployment_name(deployment.id),
          :server => eap.id,  # TODO does that make sense? What is better?
          :nativeid => deployment.id,
          :ems_ref => deployment.path
        }
      end

      def parse_deployment_name(name)
        tmp = name.dup
        tmp.sub!(/^.*deployment=/,'')
        tmp
      end

      def parse_middleware_servers(eap)
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
