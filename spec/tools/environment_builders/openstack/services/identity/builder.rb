require_relative 'builder/keystone_v2'
require_relative 'builder/keystone_v3'

module Openstack
  module Services
    module Identity
      class Builder
        def self.build_all(ems, service_type = :v2)
          builder_class = case service_type
                          when :v2
                            Openstack::Services::Identity::Builder::KeystoneV2
                          when :v3
                            Openstack::Services::Identity::Builder::KeystoneV3
                          end

          builder_class.new(ems).build_all
        end
      end
    end
  end
end
