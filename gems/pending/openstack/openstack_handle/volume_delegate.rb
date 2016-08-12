module OpenstackHandle
  class VolumeDelegate < DelegateClass(Fog::Volume::OpenStack)
    include OpenstackHandle::HandledList
    include Vmdb::Logging

    SERVICE_NAME = "Volume"

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
    end

    def snapshots_for_accessible_tenants
      ra = []
      @os_handle.service_for_each_accessible_tenant(SERVICE_NAME) do |svc|
        ra.concat(svc.list_snapshots.body['snapshots'])
      end
      ra.uniq { |s| s['id'] }
    end

    def backups_for_accessible_tenants
      ra = []
      @os_handle.service_for_each_accessible_tenant(SERVICE_NAME) do |svc|
        ra.concat(svc.list_backups.body['backups'])
      end
      ra.uniq { |s| s['id'] }
    end

    def quotas_for_current_tenant
      if current_tenant.kind_of?(Hash)
        @tenant_id ||= current_tenant['id']
      else
        # Seems like keystone v3 has string in current_tenant
        @tenant_id ||= @os_handle.accessible_tenants.detect { |x| x.name == current_tenant }.id
      end
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
