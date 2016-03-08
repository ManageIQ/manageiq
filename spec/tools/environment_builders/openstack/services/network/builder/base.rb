module Openstack
  module Services
    module Network
      class Builder
        class Base
          attr_reader :projects, :networks, :service, :floating_ips, :security_groups

          def build_all
            setup_quotas

            find_or_create_networks
            find_or_create_routers
            find_or_create_floating_ips
            find_or_create_security_groups

            self
          end

          private

          def find_or_create_security_groups
            @data.security_groups.each do |security_group|
              security_group = find_or_create(@service.security_groups, security_group.merge(:tenant_id => @project.id))
              find_or_create_firewall_rules(security_group)

              @security_groups << security_group
            end
          end
        end
      end
    end
  end
end
