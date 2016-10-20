class ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet < ::CloudSubnet
  def self.raw_create_subnet(ext_management_system, options)
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

  def self.validate_create_subnet(ext_management_system)
    validate_subnet(ext_management_system)
  end

  def provider_object(connection)
    connection.subnets.get(ems_ref)
  end

  def raw_delete_subnet
    with_provider_object(&:destroy)
    destroy!
  rescue => e
    _log.error "subnet=[#{name}], error: #{e}"
    raise MiqException::MiqCloudSubnetDeleteError, e.to_s, e.backtrace
  end

  def raw_update_subnet(options)
    with_provider_object do |subnet|
      subnet.attributes.merge!(options)
      subnet.save
    end
  rescue => e
    _log.error "subnet=[#{name}], error: #{e}"
    raise MiqException::MiqCloudSubnetUpdateError, e.to_s, e.backtrace
  end

  def validate_delete_subnet
    msg = validate_subnet
    return {:available => msg[:available], :message => msg[:message]} unless msg[:available]
    # TODO: Test if subnet
    {:available => true, :message => nil}
  end

  def validate_update_subnet
    validate_subnet
    {:available => true, :message => nil}
  end

  def with_provider_object
    super(connection_options)
  end

  private

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
