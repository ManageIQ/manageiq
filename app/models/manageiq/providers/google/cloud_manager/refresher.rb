module ManageIQ::Providers::Google
  class CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def collect_inventory_for_targets(ems, targets)
      targets.collect do |target|
        data = Hash.new { |h, k| h[k] = {} }

        case target
        when ExtManagementSystem
          get_gce_data(ems, target, data)
        when VmOrTemplate
          get_vm_data(ems, target, data)
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

    def get_vm_data(ems, target, data)
      GCE_INVENTORY_TYPES.each { |k|  data[k] = [] }

      ems.with_provider_connection do |google|
        server = google.servers.get(target.name)
        unless server.nil?
          zone_name   = parse_uid_from_url(server.zone)
          zone        = google.zones.get(zone_name) unless zone_name.nil?

          flavor_name = parse_uid_from_url(server.machine_type)
          flavor      = google.flavors.get(flavor_name) unless flavor_name.nil?

          networks = server.network_interfaces.to_a.collect do |nic|
            network_name = parse_uid_from_url(nic["network"])
            google.networks.get(network_name) unless network_name.nil?
          end

          disks = server.disks.to_a.collect do |disk|
            disk_name = parse_uid_from_url(disk["source"])
            google.disks.get(disk_name) unless disk_name.nil?
          end

          data[:project]  = google.projects.get(google.project)
          data[:zones]    << zone unless zone.nil?
          data[:flavors]  << flavor unless flavor.nil?
          data[:networks] = networks
          data[:disks]    = disks
          data[:servers]  = [server]
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

    def parse_uid_from_url(url)
      URI(url).path.split('/')[-1] unless url.nil?
    end
  end
end
