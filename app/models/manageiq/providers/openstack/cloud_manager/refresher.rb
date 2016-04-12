module ManageIQ::Providers
  class Openstack::CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_legacy_inventory(ems)
      ManageIQ::Providers::Openstack::CloudManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end

    # TODO(lsmola) NetworkManager, remove this once we have a full representation of the NetworkManager.
    # NetworkManager should refresh base on its own conditions
    def save_inventory(ems, target, hashes)
      super
      EmsRefresh.queue_refresh(ems.network_manager)
    end

    def post_process_refresh_classes
      [Vm]
    end
  end
end
