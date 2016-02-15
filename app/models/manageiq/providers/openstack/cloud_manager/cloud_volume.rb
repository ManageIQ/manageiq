class ManageIQ::Providers::Openstack::CloudManager::CloudVolume < ::CloudVolume
  include_concern 'Operations'

  def self.validate_create_volume(ext_management_system, options)
    mandatory_options = [:size, :display_name, :cloud_tenant]
    unless mandatory_options.all? { |x| !options[x].blank? }
      return validation_failed("Create Volume", "Mandatory parameters are #{mandatory_options.join(", ")}.")
    end
    validate_volume(ext_management_system)
  end

  def self.raw_create_volume(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    volume = nil

    ext_management_system.with_provider_connection(cinder_connection_options(cloud_tenant)) do |service|
      volume = service.volumes.new(options)
      volume.save
    end
    {:ems_ref => volume.id, :status => volume.status}
  rescue => e
    _log.error "volume=[#{options[:display_name]}], error: #{e}"
    raise MiqException::MiqVolumeCreateError, e.to_s, e.backtrace
  end

  def validate_update_volume
    validate_volume
  end

  def raw_update_volume(options)
    with_provider_object do |volume|
      volume.attributes.merge!(options)
      volume.save
    end
  rescue => e
    _log.error "volume=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeUpdateError, e.to_s, e.backtrace
  end

  def validate_delete_volume
    msg = validate_volume
    return {:available => msg[:available], :message => msg[:message]} unless msg[:available]
    if with_provider_object(&:status) == "in-use"
      return validation_failed("Create Volume", "Can't delete volume that is in use.")
    end
    {:available => true, :message => nil}
  end

  def raw_delete_volume
    with_provider_object(&:destroy)
  rescue => e
    _log.error "volume=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeDeleteError, e.to_s, e.backtrace
  end

  def provider_object(connection)
    connection.volumes.get(ems_ref)
  end

  def with_provider_object
    super(cinder_connection_options)
  end

  private

  def connection_options
    # TODO(lsmola) expand with cinder connection when we have Cinder v2, based on respond to on service.volumes method,
    #  but best if we can fetch endpoint list and do discovery of available versions
    nova_connection_options
  end

  def nova_connection_options
    connection_options = {:service => "Compute"}
    connection_options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    connection_options
  end

  def self.cinder_connection_options(cloud_tenant = nil)
    connection_options = {:service => "Volume"}
    connection_options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    connection_options
  end

  def cinder_connection_options
    self.class.cinder_connection_options(cloud_tenant)
  end
end
