require_relative '../data/keystone_v3'

module Openstack
  module Services
    module Identity
      class Builder
        class KeystoneV3
          attr_reader :projects, :service

          def initialize(ems)
            @service = ems.connect(:service => "Identity", :openstack_endpoint_type => 'adminURL')
            @data    = Data::KeystoneV3.new

            # Collected data
            @projects = []
            @domains  = []
          end

          def domain_id
            'default'
          end

          def build_all
            find_or_create_domains
            find_or_create_projects
            find_or_create_roles

            self
          end

          private

          def find_or_create_projects
            @data.projects.each do |project|
              openstack_project = (find(@service.projects.all(:domain_id => domain_id), project.slice(:name)) ||
                                   create_project(@service.projects, @projects, domain_id, project))
              @projects << openstack_project
            end
          end

          def create_project(service_projects, projects, domain_id, project)
            parent_id = nil
            if (parent = project.delete(:__parent_name))
              parent_id = projects.detect { |x| x.name == parent }.id
            end

            create(service_projects, project.merge(:domain_id => domain_id, :parent_id => parent_id))
          end

          def find_or_create_domains
            # TODO(lsmola) implement mutidomain support, just load domains for now
            # @domains = @service.domains
          end

          def find_or_create_roles
            @data.roles.each do |role|
              admin_user = @service.users.all(:domain_id => domain_id).detect { |x| x.name == 'admin' }
              admin_role = @service.roles.all(:domain_id => domain_id).detect { |x| x.name == role }
              @projects.each do |p|
                puts "Creating role {:name => '#{role}', :tenant_id => '#{p.name}'} role in "\
                     "Fog::Identity::OpenStack:Roles"
                begin
                  p.grant_role_to_user(admin_role.id, admin_user.id)
                rescue Excon::Errors::Conflict
                  # Tenant already has the admin role
                  puts "Finding role {:name => 'admin', :tenant_id => '#{p.name}'} role in "\
                       "Fog::Identity::OpenStack:Roles"
                end
              end
            end
          end
        end
      end
    end
  end
end
