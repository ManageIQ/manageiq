class ManageIQ::Providers::Openstack::CloudManager::CloudTenant < ::CloudTenant
  has_and_belongs_to_many :miq_templates,
                          :foreign_key             => "cloud_tenant_id",
                          :join_table              => "cloud_tenants_vms",
                          :association_foreign_key => "vm_id",
                          :class_name              => "ManageIQ::Providers::Openstack::CloudManager::Template"

  # TODO(lpichler) roles should be option in UI
  OPENSTACK_ROLES = %w(admin heat_stack_owner SwiftOperator).freeze

  def self.raw_create_cloud_tenant(cloud_manager, cloud_tenant_name, options = {})
    domain_id = cloud_manager.keystone_v3_domain_id

    create_options = {:enabled => true, :name => cloud_tenant_name, :domain_id => domain_id}
                     .merge(options)

    connection_options = {:service => "Identity", :openstack_endpoint_type => 'adminURL'}

    cloud_manager.with_provider_connection(connection_options) do |service|
      project = service.projects.create(create_options)
      grant_roles_to_user_for(project, service, cloud_manager.authentication_userid, domain_id)

      [project.id, project.parent_id]
    end
  rescue => err
    _log.error "cloud_tenant=[#{cloud_tenant_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def self.grant_roles_to_user_for(project, service, authentication_userid, domain_id)
    OPENSTACK_ROLES.each do |role|
      admin_user = service.users.all(:domain_id => domain_id).detect { |x| x.name == authentication_userid }
      admin_role = service.roles.all(:domain_id => domain_id).detect { |x| x.name == role }
      project.grant_role_to_user(admin_role.id, admin_user.id)
    end
  end
end
