module MiqProvision::Service
  def connect_to_service(vm, service, service_resource)
    unless service.nil? || service_resource.nil?
      _log.info("Connecting VM #{vm.id}:#{vm.name} to service #{service.id}:#{service.name}")
      service.add_resource!(vm, service_resource)
    end
  end

  def get_service_and_service_resource
    svc_guid = get_option(:service_guid)
    sr_id    = get_option(:service_resource_id)

    svc = ::Service.find_by(:guid => svc_guid) unless svc_guid.blank?
    sr  = ServiceResource.find_by(:id => sr_id) unless sr_id.blank?

    [svc, sr]
  end
end
