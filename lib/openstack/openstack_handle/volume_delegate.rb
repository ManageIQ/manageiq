module OpenstackHandle
  class VolumeDelegate < DelegateClass(Fog::Volume::OpenStack)
    SERVICE_NAME = "Volume"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def volumes_for_accessible_tenants
    	volumes.all(:detailed => true, :all_tenants => true)
    end

    def snapshots_for_accessible_tenants
      ra = []
      @os_handle.service_for_each_accessible_tenant(SERVICE_NAME) do |svc|
        ra.concat(svc.list_snapshots.body['snapshots'])
      end
      ra.uniq { |s| s['id'] }
    end
  end
end
