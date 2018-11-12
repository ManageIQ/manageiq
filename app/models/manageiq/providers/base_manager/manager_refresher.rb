module ManageIQ
  module Providers
    class BaseManager::ManagerRefresher < ManageIQ::Providers::BaseManager::Refresher
      def inventory_class_for(klass)
        provider_module = ManageIQ::Providers::Inflector.provider_module(klass)
        "#{provider_module}::Inventory".constantize
      end

      # Legacy inventory parser
      #
      # @param ems [ManageIQ::Providers::BaseManager] Manager we want to parse
      # @return [Array<Hash>] Array of hashes with parsed data
      def parse_legacy(ems)
        if respond_to?(:parse_legacy_inventory)
          parse_legacy_inventory(ems)
        else
          provider_module      = ManageIQ::Providers::Inflector.provider_module(ems.class)
          manager_type         = ManageIQ::Providers::Inflector.manager_type(ems.class)
          refresh_parser_class = "#{provider_module}::#{manager_type}Manager::RefreshParser".constantize
          refresh_parser_class.ems_inv_to_hashes(ems, refresher_options)
        end
      end

      # Initialize Inventory objects using builder, where based on Collector inside, inventory might be collected
      # or just provides with lazy collections evaluated in the parser. For legacy refresh, this method doesn't do
      # anything.
      #
      # @param ems [ManageIQ::Providers::BaseManager] Manager having creds for API connection
      # @param targets [Array] Array of targets which can be ManageIQ::Providers::BaseManager or InventoryRefresh::Target
      #        or InventoryRefresh::TargetCollection or ApplicationRecord we will be collecting data for.
      # @return [Array<Array>] Array of doubles [target, inventory] with target class from parameter and
      #         ManageIQ::Providers::Inventory object
      def collect_inventory_for_targets(ems, targets)
        targets_with_data = targets.collect do |target|
          target_name = target.try(:name) || target.try(:event_type)

          _log.info("Filtering inventory for #{target.class} [#{target_name}] id: [#{target.id}]...")

          if ems.inventory_object_refresh?
            inventory = inventory_class_for(ems.class).build(ems, target)
          end

          _log.info("Filtering inventory...Complete")
          [target, inventory]
        end

        targets_with_data
      end

      # Parses the data using given parsers, while getting raw data from the Collector object and storing it into
      # Persister object. For legacy refresh we invoke parse_legacy.
      # @param ems [ManageIQ::Providers::BaseManager] Manager which targets we want to parse
      # @param _target [Array] Not used in new refresh or legacy refresh by default.
      # @param inventory [ManageIQ::Providers::Inventory] Inventory object having Parsers, Collector and Persister objects
      #        that we need for parsing.
      # @return [Array<Hash> or InventoryRefresh::Persister] Returns parsed Array of hashes for legacy refresh, or
      #         Persister object containing parsed data for new refresh.
      def parse_targeted_inventory(ems, _target, inventory)
        log_header = format_ems_for_logging(ems)
        _log.debug("#{log_header} Parsing inventory...")
        hashes_or_persister, = Benchmark.realtime_block(:parse_inventory) do
          if ems.inventory_object_refresh?
            inventory.parse
          else
            parsed, _ = Benchmark.realtime_block(:parse_legacy_inventory) { parse_legacy(ems) }
            parsed
          end
        end
        _log.debug("#{log_header} Parsing inventory...Complete")

        hashes_or_persister
      end

      # We preprocess targets to merge all non ExtManagementSystem class targets into one
      # InventoryRefresh::TargetCollection. This way we can do targeted refresh of all queued targets in 1 refresh
      def preprocess_targets
        @targets_by_ems_id.each do |ems_id, targets|
          ems = @ems_by_ems_id[ems_id]

          if targets.any? { |t| t.kind_of?(ExtManagementSystem) }
            targets_for_log = targets.map { |t| "#{t.class} [#{t.name}] id [#{t.id}] " }
            _log.info("Defaulting to full refresh for EMS: [#{ems.name}], id: [#{ems.id}], from targets: #{targets_for_log}") if targets.length > 1
          end

          # We want all targets of class EmsEvent to be merged into one target, so they can be refreshed together, otherwise
          # we could be missing some crosslinks in the refreshed data
          all_targets, sub_ems_targets = targets.partition { |x| x.kind_of?(ExtManagementSystem) }

          if sub_ems_targets.present?
            if ems.allow_targeted_refresh?
              # We can disable targeted refresh with a setting, then we will just do full ems refresh on any event
              ems_event_collection = InventoryRefresh::TargetCollection.new(:targets    => sub_ems_targets,
                                                                            :manager_id => ems_id)
              all_targets << ems_event_collection
            else
              all_targets << @ems_by_ems_id[ems_id]
            end
          end

          @targets_by_ems_id[ems_id] = all_targets
        end

        super
      end
    end
  end
end
