class ManageIQ::Providers::Redhat::InfraManager
  class Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def collect_inventory_for_targets(ems, targets)
      inventory = ems.rhevm_inventory
      raise "Invalid RHEV server ip address." if inventory.api.nil?

      # TODO before iterating over targets it would be good to check whether ExtMgmntSystem is part of it
      # TODO optimize not to fetch the same objects like clusters for multiple targets

      targets_with_data = targets.collect do |target|
        _log.info "Filtering inventory for #{target.class} [#{target.name}] id: [#{target.id}]..."

        case target
        when Host
          methods = {
            :primary => {
              :host        => target.ems_ref,
            },
            :secondary => {
              :host        => [:statistics, :host_nics],
            }
          }
          data,  = Benchmark.realtime_block(:fetch_host_data) { data = inventory.targeted_refresh(methods) }

        when VmOrTemplate
          require 'uri'

          vm = target.ems_ref
          vm_id = URI(vm).path.split('/').last

          methods = {
            :primary => {
              :cluster     => target.parent_cluster.ems_ref,
              :data_center => target.parent_datacenter.ems_ref,
              :vm          => vm,
              :template    => "/api/templates?search=vm.id=#{vm_id}",
              :storage     => target.storages.map(&:ems_ref)
            },
            :secondary => {
              :vm         => [:disks, :snapshots, :nics],
              :template   => [:disks]
            }
          }
          data,  = Benchmark.realtime_block(:fetch_vm_data) { inventory.targeted_refresh(methods) }

        else
          data,  = Benchmark.realtime_block(:fetch_all) { inventory.refresh }

        end

        _log.info "Filtering inventory...Complete"
        [target, data]
      end

      ems.api_version = inventory.service.version_string
      ems.save

      targets_with_data
    end

    def parse_targeted_inventory(ems, _target, inventory)
      log_header = format_ems_for_logging(ems)
      _log.debug "#{log_header} Parsing inventory..."
      hashes, = Benchmark.realtime_block(:parse_inventory) do
        RefreshParser.ems_inv_to_hashes(inventory)
      end
      _log.debug "#{log_header} Parsing inventory...Complete"

      hashes
    end

    def post_process_refresh_classes
      [::VmOrTemplate, ::Host]
    end
  end
end
