require_relative 'builder/neutron'
require_relative 'builder/nova'

module Openstack
  module Services
    module Network
      class Builder
        def self.build_all(ems, project, service_type = :neutron)
          builder_class = case service_type
                          when :neutron
                            Openstack::Services::Network::Builder::Neutron
                          when :nova
                            Openstack::Services::Network::Builder::Nova
                          end

          builder_class.new(ems, project).build_all
        end
      end
    end
  end
end
