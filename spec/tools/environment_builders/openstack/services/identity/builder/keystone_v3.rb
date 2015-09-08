require_relative '../data/keystone_v3'

module Openstack
  module Services
    module Identity
      class Builder
        class KeystoneV3
          attr_reader :projects, :service

          def initialize(ems)
            @service = ems.connect(:service => "Identity")
            @data    = Data::KeystoneV3.new

            # Collected data
            @projects = []
          end

          def build_all
            find_or_create_projects
            find_or_create_roles

            self
          end

          private

          def find_or_create_projects
            @data.projects.each do |project|
              @projects << find_or_create(@service.projects, project)
            end
          end

          def find_or_create_roles
            @data.roles.each do |role|
              admin_user = @service.users.detect { |x| x.name == role }
              admin_role = @service.roles.detect { |x| x.name == role }
              @projects.each do |p|
                begin
                  p.grant_role_to_user(admin_role.id, admin_user.id)
                rescue Excon::Errors::Conflict
                  # Tenant already has the admin role
                  puts "Finding role {:name => 'admin', :tenant_id => '#{p.name}'} role in Fog::Identity::OpenStack:Roles"
                end
              end
            end
          end
        end
      end
    end
  end
end
