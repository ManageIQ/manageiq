module ManageIQ::Providers::StorageManager::SwiftManager::RefreshParser::CrossLinkers
  class Openstack
    include Vmdb::Logging

    def initialize(parent_ems, data)
      @parent_ems = parent_ems
      @data       = data

      @parent_ems.cloud_object_store_containers.reset
      @parent_ems.cloud_object_store_objects.reset
    end

    def cross_link
      @data[:cloud_object_store_containers]&.each do |container_hash|
        link_to_tenant(container_hash)
      end

      @data[:cloud_object_store_objects]&.each do |object_hash|
        link_to_tenant(object_hash)
      end
    end

    def link_to_tenant(hash)
      tenant_id = hash[:tenant_id]
      tenant = @parent_ems.cloud_tenants.detect { |t| t.ems_ref == tenant_id }
      unless tenant
        _log.info("EMS: #{@parent_ems.name}, tenant not found: #{tenant_id}")
        return
      end
      _log.debug("Found tenant: #{tenant_id}, id = #{tenant.id}")

      hash[:cloud_tenant_id] = tenant.id
    end
  end
end
