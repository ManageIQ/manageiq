class ManageIQ::Providers::Redhat::InfraManager
  class Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_legacy_inventory(ems)
      rhevm = ems.rhevm_inventory
      raise "Invalid RHEV server ip address." if rhevm.api.nil?

      raw_ems_data = rhevm.refresh
      return [] if raw_ems_data.blank?

      #TODO cleanup with @ems_data
      ems.api_version = rhevm.service.version_string
      ems.save

      RefreshParser.ems_inv_to_hashes(raw_ems_data)
    end

    def post_process_refresh_classes
      [::VmOrTemplate, ::Host]
    end
  end
end
