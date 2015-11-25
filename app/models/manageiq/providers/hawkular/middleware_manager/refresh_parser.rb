module ManageIQ::Providers
  module Hawkular
    class MiddlewareManager::RefreshParser
      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems = ems
      end

      def ems_inv_to_hashes
        @data = {}
        @data[:middleware_servers] = get_middleware_servers
        @data
      end

      def get_middleware_servers
        @ems.feeds.map do |feed|
          @ems.eaps(feed).map do |eap|
            parse_middleware_servers(eap)
          end
        end.flatten
      end

      def parse_middleware_servers(eap)
        {
          :name       => eap.feed,
          :ems_ref    => eap.path,
          :nativeid   => eap.id,
          :type_path  => eap.type_path,
          :properties => eap.properties
        }
      end
    end
  end
end
