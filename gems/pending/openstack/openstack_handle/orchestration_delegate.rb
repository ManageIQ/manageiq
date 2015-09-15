module OpenstackHandle
  class OrchestrationDelegate < DelegateClass(Fog::Orchestration::OpenStack)
    include OpenstackHandle::HandledList
    include Vmdb::Logging

    SERVICE_NAME = "Orchestration"

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
    end

    def stacks_for_accessible_tenants(opts = {})
      ra = []
      @os_handle.service_for_each_accessible_tenant(SERVICE_NAME) do |svc|
        not_found_error = Fog.const_get(SERVICE_NAME)::OpenStack::NotFound

        rv = begin
          svc.stacks.all(opts)
        rescue not_found_error => e
          $fog_log.warn("MIQ(#{self.class.name}.#{__method__}) HTTP 404 Error during OpenStack request. " \
                        "Skipping inventory item #{SERVICE_NAME} stacks\n#{e}")
          nil
        end

        ra.concat(rv.to_a) if rv
      end
      ra
    end
  end
end
