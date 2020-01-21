require_relative '../data/keystone_v2'

module Openstack
  module Services
    module Identity
      class Builder
        class KeystoneV2
          attr_reader :projects, :service

          def initialize(ems)
            @service = ems.connect(:service => "Identity", :openstack_endpoint_type => 'adminURL')
            @data    = Data::KeystoneV2.new

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
              @projects << find_or_create(@service.tenants, project)
            end
          end

          def find_or_create_roles
            @data.roles.each do |role|
              admin_user = @service.users.find_by(:name => 'admin')
              admin_role = @service.roles.detect { |x| x.name == role }
              if admin_role.blank?
                puts "Skipping role: '#{role}', as it doesn't exist in this environment."
                next
              end
              @projects.each do |p|
                puts "Creating role {:name => '#{role}', :tenant_id => '#{p.name}'} role in "\
                     "Fog::Identity::OpenStack:Roles"
                begin
                  p.grant_user_role(admin_user.id, admin_role.id)
                rescue Excon::Errors::Conflict
                  # Tenant already has the admin role
                  puts "Finding role {:name => '#{role}', :tenant_id => '#{p.name}'} role in"\
                       " Fog::Identity::OpenStack:Roles"
                end
              end
            end
          end
        end
      end
    end
  end
end
