module OpenstackHandle
  class VolumeDelegate < DelegateClass(Fog::Volume::OpenStack)
    SERVICE_NAME = "Volume"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def volumes_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :volumes, :id)
    end

    def snapshots_for_accessible_tenants
      ra = []
      @os_handle.service_for_each_accessible_tenant(SERVICE_NAME) do |svc|
        ra.concat(svc.list_snapshots.body['snapshots'])
      end
      ra.uniq { |s| s['id'] }
    end

    def quotas_for_current_tenant
      @tenant_id ||= current_tenant['id']
      q = get_quota(@tenant_id).body['quota_set']
      # looks like the quota id and the tenant id are the same,
      # but set the tenant id anyway, just in case.
      q.merge!('tenant_id' => @tenant_id, 'service_name' => SERVICE_NAME)
    end

    def quotas_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :quotas_for_current_tenant, 'id', false)
    end
  end
end
