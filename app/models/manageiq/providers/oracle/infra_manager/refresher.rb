class ManageIQ::Providers::Oracle::InfraManager
  class Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_inventory(ems, _targets)
      service = ems.oraclevm_service

      managers = service.managers
      return [] if managers.empty?

      manager = managers[0]

      ems.api_version = manager.manager_version
      ems.save

      RefreshParser.service_to_hashes(service)
    end

    def save_inventory(ems, targets, hashes)
      EmsRefresh.save_ems_inventory(ems, hashes, targets[0])
    end

    def post_process_refresh_classes
      [::VmOrTemplate, ::Host]
    end
  end
end
