class ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup < ::SecurityGroup
  supports :create

  supports :delete do
    if ext_management_system.nil?
      unsupported_reason_add(:delete_security_group, _("The Security Group is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end

  supports :update do
    if ext_management_system.nil?
      unsupported_reason_add(:update_security_group, _("The Security Group is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end

  def self.raw_create_security_group(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    security_group = nil
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      security_group = service.create_security_group(options).body
    end
    {:ems_ref => security_group['id'], :name => options[:name]}
  rescue => e
    _log.error "security_group=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqSecurityGroupCreateError, e.to_s, e.backtrace
  end

  def raw_delete_security_group
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.delete_security_group(ems_ref)
    end
  rescue => e
    _log.error "security_group=[#{name}], error: #{e}"
    raise MiqException::MiqSecurityGroupDeleteError, e.to_s, e.backtrace
  end

  def delete_security_group_queue(userid)
    task_opts = {
      :action => "deleting Security Group for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_delete_security_group',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_update_security_group(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.update_security_group(ems_ref, options)
    end
  rescue => e
    _log.error "security_group=[#{name}], error: #{e}"
    raise MiqException::MiqSecurityGroupUpdateError, e.to_s, e.backtrace
  end

  def update_security_group_queue(userid, options = {})
    task_opts = {
      :action => "updating Security Group for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_update_security_group',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = {:service => "Network"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  private

  def connection_options(cloud_tenant = nil)
    self.class.connection_options(cloud_tenant)
  end
end
