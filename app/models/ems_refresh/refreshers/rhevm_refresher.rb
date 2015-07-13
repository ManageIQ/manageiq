module EmsRefresh::Refreshers
  class RhevmRefresher < BaseRefresher
    include RefresherRelatsMixin
    include EmsRefresherMixin

    def parse_inventory(ems, _targets)
      rhevm = ems.rhevm_inventory
      raise "Invalid RHEV server ip address." if rhevm.api.nil?

      raw_ems_data = rhevm.refresh
      return [] if raw_ems_data.blank?

      ems.api_version = rhevm.service.version_string
      ems.save

      EmsRefresh::Parsers::Rhevm.ems_inv_to_hashes(raw_ems_data)
    end

    def save_inventory(ems, targets, hashes)
      EmsRefresh.save_ems_inventory(ems, hashes, targets[0])
    end

    def post_process_refresh_classes
      [VmOrTemplate, Host]
    end
  end
end
