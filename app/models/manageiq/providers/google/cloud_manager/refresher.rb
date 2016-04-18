module ManageIQ::Providers::Google
  class CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def collect_inventory_for_targets(ems, targets)
      targets.collect do |target|
        data = Hash.new { |h, k| h[k] = {} }

        case target
        when ExtManagementSystem, VmOrTemplate
          get_gce_data(ems, target, data)
        end

        [target, data]
      end
    end

    GCE_INVENTORY_TYPES = [
      :zones,
      :flavors,
      :networks,
      :firewalls,
      :disks,
      :snapshots,
      :images,
      :servers
    ].freeze

    def get_gce_data(ems, _target, data)
      ems.with_provider_connection do |google|
        data[:project] = google.projects.get(google.project)

        GCE_INVENTORY_TYPES.each do |type|
          data[type] = google.send(type).all
        end
      end
    end

    def parse_targeted_inventory(_ems, _target, inventory)
      ManageIQ::Providers::Google::CloudManager::RefreshParser.ems_inv_to_hashes(inventory, refresher_options)
    end

    def save_inventory(ems, _targets, hashes)
      EmsRefresh.save_ems_inventory(ems, hashes)
      EmsRefresh.queue_refresh(ems.network_manager)
    end

    def post_process_refresh_classes
      [::Vm]
    end
  end
end
