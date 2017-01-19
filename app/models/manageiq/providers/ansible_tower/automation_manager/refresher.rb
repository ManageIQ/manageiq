module ManageIQ::Providers
  module AnsibleTower
    class AutomationManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
      include ::EmsRefresh::Refreshers::EmsRefresherMixin

      def collect_inventory_for_targets(ems, targets)
        ems.with_provider_connection do |connection|
          # FIXME: this should really be somewhere else
          ems.api_version = connection.api.version
          ems.save
        end

        targets.collect do |target|
          target_name = target.try(:name)

          _log.info "Collecting inventory for #{target.class} [#{target_name}] id: [#{target.id}]..."

          inventory = ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker::Collector.new(ems)

          _log.info "Collecting inventory...Complete"
          [target, inventory]
        end
      end

      def parse_targeted_inventory(ems, target, inventory)
        log_header = format_ems_for_logging(ems)
        _log.debug "#{log_header} Parsing inventory..."
        hashes, = Benchmark.realtime_block(:parse_inventory) do
          ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker::Parser.new(ems, target, inventory).parse
        end
        _log.debug "#{log_header} Parsing inventory...Complete"

        hashes
      end
    end
  end
end
