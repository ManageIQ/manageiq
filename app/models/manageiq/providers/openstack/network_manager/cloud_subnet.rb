class ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet < ::CloudSubnet
  supports :create
  supports :delete do
    if ext_management_system.nil?
      unsupported_reason_add(:delete_subnet, _("The subnet is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end
  supports :update do
    if ext_management_system.nil?
      unsupported_reason_add(:update_subnet, _("The subnet is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end

  def self.raw_create_subnet(ext_management_system, options)
    # TODO: remove this log line once this uses the task queue, as the task queue has its own logging
    _log.info "Command: #{self.class.name}##{__method__}, Args: #{options.inspect}"
    cloud_tenant = options.delete(:cloud_tenant)
    subnet = nil

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      subnet = service.subnets.new(options)
      subnet.save
    end
    {:ems_ref => subnet.id, :name => options[:name]}
  rescue => e
    _log.error "subnet=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqCloudSubnetCreateError, e.to_s, e.backtrace
  end

  def provider_object(connection)
    connection.subnets.get(ems_ref)
  end

  def raw_delete_subnet
    # TODO: remove this log line once this uses the task queue, as the task queue has its own logging
    _log.info "Command: #{self.class.name}##{__method__}, ID: #{id}"
    with_provider_object(&:destroy)
    destroy!
  rescue => e
    _log.error "subnet=[#{name}], error: #{e}"
    raise MiqException::MiqCloudSubnetDeleteError, e.to_s, e.backtrace
  end

  def raw_update_subnet(options)
    # TODO: remove this log line once this uses the task queue, as the task queue has its own logging
    _log.info "Command: #{self.class.name}##{__method__}, ID: #{id}, Args: #{options.inspect}"
    with_provider_object do |subnet|
      subnet.attributes.merge!(options)
      subnet.save
    end
  rescue => e
    _log.error "subnet=[#{name}], error: #{e}"
    raise MiqException::MiqCloudSubnetUpdateError, e.to_s, e.backtrace
  end

  def with_provider_object
    super(connection_options)
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = {:service => "Network"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end
  private_class_method :connection_options

  private

  def connection_options(cloud_tenant = nil)
    self.class.connection_options(cloud_tenant)
  end
end
