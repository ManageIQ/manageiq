module ManageIQ
  module Providers
    class BaseManager::Refresher
      class PartialRefreshError < StandardError; end

      include Vmdb::Logging

      attr_accessor :ems_by_ems_id, :targets_by_ems_id

      def self.refresh(targets)
        new(targets).refresh
      end

      def initialize(targets)
        group_targets_by_ems(targets)
      end

      def options
        return @options if defined?(@options)
        @options = Settings.ems_refresh
      end

      def refresher_options
        options[self.class.ems_type]
      end

      def refresh
        preprocess_targets
        partial_refresh_errors = []

        @targets_by_ems_id.each do |ems_id, targets|
          # Get the ems object
          ems = @ems_by_ems_id[ems_id]
          ems_refresh_start_time = Time.now

          begin
            _log.info("Refreshing all targets...")
            log_ems_target = format_ems_for_logging(ems)
            _log.info("#{log_ems_target} Refreshing targets for EMS...")
            targets.each { |t| _log.info("#{log_ems_target}   #{t.class} [#{t.name}] id [#{t.id}]") }
            _, timings = Benchmark.realtime_block(:ems_refresh) { refresh_targets_for_ems(ems, targets) }
            _log.info("#{log_ems_target} Refreshing targets for EMS...Complete - Timings #{timings.inspect}")
          rescue => e
            raise if EmsRefresh.debug_failures

            _log.error("#{log_ems_target} Refresh failed")
            _log.log_backtrace(e)
            _log.error("#{log_ems_target} Unable to perform refresh for the following targets:")
            targets.each do |target|
              target = target.first if target.kind_of?(Array)
              _log.error(" --- #{target.class} [#{target.name}] id [#{target.id}]")
            end

            # record the failed status and skip post-processing
            ems.update(:last_refresh_error => e.to_s, :last_refresh_date => Time.now.utc)
            partial_refresh_errors << e.to_s
            next
          ensure
            post_refresh_ems_cleanup(ems, targets)
          end

          ems.update(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
          post_refresh(ems, ems_refresh_start_time)
        end

        _log.info("Refreshing all targets...Complete")
        raise PartialRefreshError, partial_refresh_errors.join(', ') if partial_refresh_errors.any?
      end

      def preprocess_targets
        preprocess_targets_manager_refresh
        preprocess_targets_full_refresh_threshold
      end

      def refresh_targets_for_ems(ems, targets)
        # handle a 4-part inventory refresh process
        # 1. collect inventory
        # 2. parse inventory
        # 3. save inventory
        # 4. post process inventory (only when using InventoryCollections)
        log_header = format_ems_for_logging(ems)

        targets_with_inventory, _ = Benchmark.realtime_block(:collect_inventory_for_targets) do
          collect_inventory_for_targets(ems, targets)
        end

        until targets_with_inventory.empty?
          target, inventory = targets_with_inventory.shift

          _log.info("#{log_header} Refreshing target #{target.class} [#{target.name}] id [#{target.id}]...")
          parsed, _ = Benchmark.realtime_block(:parse_targeted_inventory) do
            parse_targeted_inventory(ems, target, inventory)
          end
          inventory = nil # clear to help GC

          Benchmark.realtime_block(:save_inventory) { save_inventory(ems, target, parsed) }
          _log.info "#{log_header} Refreshing target #{target.class} [#{target.name}] id [#{target.id}]...Complete"
        end
      end

      def collect_inventory_for_targets(ems, targets)
        # TODO: implement this method in all refreshers and remove from here
        # legacy refreshers collect inventory during the parse phase so the
        # inventory component of the return value is empty
        # TODO: Update the docs/comment here to show the *real* bell-shaped
        # targeted inventory
        #
        # override this method and return an array of:
        #   [[target1, inventory_for_target1], [target2, inventory_for_target2]]
        targets.map do |target|
          inventory = inventory_class_for(ems.class).build(ems, target)
          inventory.collect!
          [target, inventory]
        end
      end

      def parse_targeted_inventory(ems, _target, inventory)
        # legacy refreshers collect inventory during the parse phase
        # new refreshers should override this method to parse inventory
        # TODO: remove this call after all refreshers support retrieving
        # inventory separate from parsing
        log_header = format_ems_for_logging(ems)
        _log.debug("#{log_header} Parsing inventory...")

        persister = inventory.parse

        _log.debug("#{log_header} Parsing inventory...Complete")

        persister
      end

      # Saves the inventory to the DB
      #
      # @param ems [ManageIQ::Providers::BaseManager]
      # @param target [ManageIQ::Providers::BaseManager or InventoryRefresh::Target or InventoryRefresh::TargetCollection]
      # @param parsed [Array<Hash> or ManageIQ::Providers::Inventory::Persister]
      def save_inventory(ems, _target, persister)
        InventoryRefresh::SaveInventory.save_inventory(ems, persister.inventory_collections)
      end

      def post_refresh_ems_cleanup(_ems, _targets)
        # Clean up any resources opened during inventory collection
      end

      def post_process_refresh_classes
        # Return the list of classes that need post processing
        []
      end

      def post_refresh(ems, ems_refresh_start_time)
        log_ems_target = "EMS: [#{ems.name}], id: [#{ems.id}]"
        # Do any post-operations for this EMS
        post_process_refresh_classes.each do |klass|
          next unless klass.respond_to?(:post_refresh_ems)
          _log.info("#{log_ems_target} Performing post-refresh operations for #{klass} instances...")
          klass.post_refresh_ems(ems.id, ems_refresh_start_time)
          _log.info("#{log_ems_target} Performing post-refresh operations for #{klass} instances...Complete")
        end
      end

      private

      def self.ems_type
        @ems_type ||= parent.ems_type.to_sym
      end

      def inventory_class_for(klass)
        provider_module = ManageIQ::Providers::Inflector.provider_module(klass)
        "#{provider_module}::Inventory".constantize
      end

      def group_targets_by_ems(targets)
        non_ems_targets = targets.select { |t| !t.kind_of?(ExtManagementSystem) && t.respond_to?(:ext_management_system) }
        MiqPreloader.preload(non_ems_targets, :ext_management_system)

        self.ems_by_ems_id     = {}
        self.targets_by_ems_id = Hash.new { |h, k| h[k] = [] }

        targets.each do |t|
          if t.kind_of?(InventoryRefresh::Target)
            ems_by_ems_id[t.manager_id] ||= t.manager
            targets_by_ems_id[t.manager_id] << t
          else
            ems = case
                  when t.respond_to?(:ext_management_system) then t.ext_management_system
                  when t.respond_to?(:manager)               then t.manager
                  else                                            t
                  end
            if ems.nil?
              _log.warn("Unable to perform refresh for #{t.class} [#{t.name}] id [#{t.id}], since it is not on an EMS.")
              next
            end

            ems_by_ems_id[ems.id] ||= ems
            targets_by_ems_id[ems.id] << t
          end
        end
      end

      # We preprocess targets to merge all non ExtManagementSystem class targets into one
      # InventoryRefresh::TargetCollection. This way we can do targeted refresh of all queued targets in 1 refresh
      def preprocess_targets_manager_refresh
        @targets_by_ems_id.each do |ems_id, targets|
          ems = @ems_by_ems_id[ems_id]

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
      end

      def preprocess_targets_full_refresh_threshold
        @full_refresh_threshold = options[:full_refresh_threshold] || 10

        # See if any should be escalated to a full refresh
        @targets_by_ems_id.each do |ems_id, targets|
          ems = @ems_by_ems_id[ems_id]
          ems_in_list = targets.any? { |t| t.kind_of?(ExtManagementSystem) }

          if ems_in_list
            _log.info("Defaulting to full refresh for EMS: [#{ems.name}], id: [#{ems.id}].") if targets.length > 1
            targets.clear << ems
          elsif targets.length >= @full_refresh_threshold
            _log.info("Escalating to full refresh for EMS: [#{ems.name}], id: [#{ems.id}].")
            targets.clear << ems
          end
        end
      end

      def refresher_type
        self.class.parent.short_token
      end

      def format_ems_for_logging(ems)
        "EMS: [#{ems.name}], id: [#{ems.id}]"
      end
    end
  end
end
