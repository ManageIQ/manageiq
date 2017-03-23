class ManageIQ::Providers::Openstack::Inventory::Collector::CloudManager < ManagerRefresh::Inventory::Collector
  include ManageIQ::Providers::Openstack::RefreshParserCommon::HelperMethods
  include Vmdb::Logging

  def connection
    @os_handle ||= manager.openstack_handle
    @connection ||= manager.connect
  end

  def compute_service
    connection
  end

  def image_service
    @image_service ||= manager.openstack_handle.detect_image_service
  end

  def network_service
    @network_service ||= manager.openstack_handle.detect_network_service
  end

  def nfv_service
    @nfv_service ||= manager.openstack_handle.detect_nfv_service
  end

  def volume_service
    @volume_service ||= manager.openstack_handle.detect_volume_service
  end

  def orchestration_service
    @orchestration_service ||= manager.openstack_handle.detect_orchestration_service
  end

  def availability_zones_compute
    @availability_zones_compute ||= safe_list { compute_service.availability_zones.summary }
  end

  def availability_zones_volume
    @availability_zones_volume ||= safe_list { volume_service.availability_zones.summary }
  end

  def availability_zones
    (availability_zones_compute + availability_zones_volume).uniq(&:zoneName)
  end

  def cloud_services
    @cloud_services ||= compute_service.handled_list(:services)
  end

  def flavors
    @flavors = connection.handled_list(:flavors)
  end

  def find_flavor(flavor_id)
    flavor = flavors_by_id[flavor_id]
    if flavor.nil?
      # the flavor might be private, which the flavor list api
      # doesn't seem to handle correctly. Try to get it separately.
      flavor = private_flavor(flavor_id)
    end
    flavor
  end

  def private_flavor(flavor_id)
    flavor = safe_get { connection.flavors.get(flavor_id) }
    if flavor
      flavors_by_id[flavor_id] = flavor
    end
  end

  def tenant_ids_with_flavor_access(flavor_id)
    unparsed_tenants = safe_list { connection.list_tenants_with_flavor_access(flavor_id) }
    flavor_access = unparsed_tenants.data[:body]["flavor_access"]
    flavor_access.map { |t| t['tenant_id'] }
  end

  def flavors_by_id
    @flavors_by_id ||= Hash[flavors.collect { |f| [f.id, f] }]
  end

  def host_aggregates
    @host_aggregates ||= compute_service.aggregates.all
  end

  def images
    @images ||= image_service.handled_list(:images)
  end

  def key_pairs
    @key_pairs ||= compute_service.handled_list(:key_pairs)
  end

  def quotas
    quotas = safe_list { compute_service.quotas_for_accessible_tenants }
    quotas.concat(safe_list { volume_service.quotas_for_accessible_tenants }) if volume_service.name == :cinder
    # TODO(lsmola) can this somehow be moved under NetworkManager
    quotas.concat(safe_list { network_service.quotas_for_accessible_tenants }) if network_service.name == :neutron
    quotas
  end

  def servers
    @servers ||= compute_service.handled_list(:servers)
  end

  def tenants
    @tenants ||= manager.openstack_handle.accessible_tenants
  end

  def vnfs
    return [] unless nfv_service
    nfv_service.handled_list(:vnfs)
  end

  def vnfds
    return [] unless nfv_service
    nfv_service.handled_list(:vnfds)
  end

  def orchestration_stacks
    return [] unless orchestration_service
    # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
    # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
    # can't get list of detailed stacks in one API call.
    orchestration_service.handled_list(:stacks, :show_nested => true).collect(&:details)
  rescue Excon::Errors::Forbidden
    # Orchestration service is detected but not open to the user
    $log.warn("Skip refreshing stacks because the user cannot access the orchestration service")
    []
  end

  def orchestration_outputs(stack)
    safe_list { stack.outputs }
  end

  def orchestration_parameters(stack)
    safe_list { stack.parameters }
  end

  def orchestration_resources(stack)
    safe_list { stack.resources }
  end

  def orchestration_template(stack)
    safe_call { stack.template }
  end
end
