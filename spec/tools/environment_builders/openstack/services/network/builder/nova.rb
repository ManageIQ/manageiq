require_relative '../data/nova'
require_relative 'base'

module Openstack
  module Services
    module Network
      class Builder
        class Nova < ::Openstack::Services::Network::Builder::Base
          def initialize(ems, project)
            @service = ems.connect(:tenant_name => project.name)
            @data    = Data::Nova.new
            @project = project

            # Collected data
            @networks             = []
            @subnets              = []
            @routers              = []
            @floating_ips         = []
            @security_groups      = []
            @security_group_rules = []
          end

          def free_floating_ips
            floating_ips.select { |x| x.instance_id.blank? }
          end

          def floating_ip_address(floating_ip)
            floating_ip.ip
          end

          private

          # TBD whole nova
          def setup_quotas
            # Not supported by nova
          end

          def find_or_create_networks
            # Not supported by nova
          end

          def find_or_create_routers
            # Not supported by nova
          end

          def find_or_create_floating_ips
            # Floating IP pool nova created by default, probablyt not worth do do mere here,
            # since nova netwroking is dead
            pool_name = 'nova'

            return if (floating_ips_count = @data.floating_ips(pool_name)).blank?

            collection = @service.addresses
            @floating_ips += found = collection.all

            puts "Finding #{found.count} floating ips in #{collection.class.name} for nova pool #{pool_name}"

            missing = floating_ips_count - found.count
            return unless missing > 0

            puts "Creating #{missing} floating ips in #{collection.class.name} for nova pool #{pool_name}"
            (1..missing).each do
              @floating_ips << collection.create
            end
          end

          def find_or_create_firewall_rules(security_group)
            return if (rules = @data.security_group_rules(security_group.name)).blank?

            rules.each do |attributes|
              @security_group_rules << (find_firewall_rule(security_group, attributes) ||
                                        create_firewall_rule(security_group, attributes))
            end
          end

          def find_firewall_rule(security_group, attributes)
            collection = security_group.security_group_rules

            rule = {:ip_range => {}}.merge(attributes)
            rule[:parent_group_id] = security_group.id

            find(collection, rule)
          end

          def create_firewall_rule(security_group, attributes)
            collection = security_group.security_group_rules
            puts "Creating nova security group rule #{attributes.inspect} in #{collection.class.name}"
            attributes[:parent_group_id]  = security_group.id
            attributes[:group]            = security_group.id if attributes[:group]
            collection.create(attributes)
          end
        end
      end
    end
  end
end
