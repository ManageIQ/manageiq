module ManageIQ::Providers
  class Openstack::CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_inventory(ems, _targets)
      ManageIQ::Providers::Openstack::CloudManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def post_process_refresh_classes
      [Vm]
    end
  end
end
