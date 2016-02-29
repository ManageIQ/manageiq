module ManageIQ::Providers
  class Openstack::NetworkManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_inventory(ems, _targets)
      ManageIQ::Providers::Openstack::NetworkManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    def post_process_refresh_classes
      []
    end
  end
end
