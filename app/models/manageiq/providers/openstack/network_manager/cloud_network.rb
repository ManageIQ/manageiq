class ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork < ::CloudNetwork
  require_nested :Private
  require_nested :Public

  def self.remapping(options)
    new_options = options.dup
    new_options[:router_external] = options[:external_facing] if options[:external_facing]
    new_options.delete(:external_facing)
    new_options
  end

  def self.raw_create_network(ext_management_system, options)
    # TODO: remove this log line once this uses the task queue, as the task queue has its own logging
    _log.info "Command: #{self.class.name}##{__method__}, Args: #{options.inspect}"
    cloud_tenant = options.delete(:cloud_tenant)
    network = nil
    raw_options = remapping(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      network = service.networks.new(raw_options)
      network.save
    end
    {:ems_ref => network.id, :name => options[:name]}
  rescue => e
    _log.error "network=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqNetworkCreateError, e.to_s, e.backtrace
  end

  def self.validate_create_network(ext_management_system)
    validate_network(ext_management_system)
  end

  def provider_object(connection)
    connection.networks.get(ems_ref)
  end

  def raw_delete_network
    # TODO: remove this log line once this uses the task queue, as the task queue has its own logging
    _log.info "Command: #{self.class.name}##{__method__}, ID: #{id}"
    with_provider_object(&:destroy)
    destroy!
  rescue => e
    _log.error "network=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkDeleteError, e.to_s, e.backtrace
  end

  def raw_update_network(options)
    # TODO: remove this log line once this uses the task queue, as the task queue has its own logging
    _log.info "Command: #{self.class.name}##{__method__}, ID: #{id}, Args: #{options.inspect}"
    with_provider_object do |network|
      network.attributes.merge!(options)
      network.save
    end
  rescue => e
    _log.error "network=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkUpdateError, e.to_s, e.backtrace
  end

  def validate_delete_network
    msg = validate_network
    return {:available => msg[:available], :message => msg[:message]} unless msg[:available]
    # TODO: Test network is used?
    {:available => true, :message => nil}
  end

  def validate_update_network
    validate_network
    {:available => true, :message => nil}
  end

  def with_provider_object
    super(connection_options)
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
