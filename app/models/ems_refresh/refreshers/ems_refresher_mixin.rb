module EmsRefresh
  module Refreshers
    module EmsRefresherMixin
      class PartialRefreshError < StandardError; end

      def format_ems_for_logging(ems)
        "EMS: [#{ems.name}], id: [#{ems.id}]"
      end

      def refresh
        preprocess_targets
        partial_refresh_errors = []

        @targets_by_ems_id.each do |ems_id, targets|
          # Get the ems object
          ems = @ems_by_ems_id[ems_id]
          ems_refresh_start_time = Time.now

          begin
            _log.info "Refreshing all targets..."
            log_ems_target = format_ems_for_logging(ems)
            _log.info "#{log_ems_target} Refreshing targets for EMS..."
            targets.each { |t| _log.info "#{log_ems_target}   #{t.class} [#{t.name}] id [#{t.id}]" }
            _, timings = Benchmark.realtime_block(:ems_refresh) { refresh_targets_for_ems(ems, targets) }
            _log.info "#{log_ems_target} Refreshing targets for EMS...Complete - Timings #{timings.inspect}"
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
            ems.update_attributes(:last_refresh_error => e.to_s, :last_refresh_date => Time.now.utc)
            partial_refresh_errors << e.to_s
            next
          ensure
            post_refresh_ems_cleanup(ems, targets)
          end

          ems.update_attributes(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
          post_refresh(ems, ems_refresh_start_time)
        end

        _log.info "Refreshing all targets...Complete"
        raise PartialRefreshError, partial_refresh_errors.join(', ') if partial_refresh_errors.any?
      end

      def preprocess_targets
        @full_refresh_threshold = options[:full_refresh_threshold] || 10

        # See if any should be escalated to a full refresh
        @targets_by_ems_id.each do |ems_id, targets|
          ems = @ems_by_ems_id[ems_id]
          ems_in_list = targets.any? { |t| t.kind_of?(ExtManagementSystem) }

          if ems_in_list
            _log.info "Defaulting to full refresh for EMS: [#{ems.name}], id: [#{ems.id}]." if targets.length > 1
            targets.clear << ems
          elsif targets.length >= @full_refresh_threshold
            _log.info "Escalating to full refresh for EMS: [#{ems.name}], id: [#{ems.id}]."
            targets.clear << ems
          end
        end
      end

      def refresh_targets_for_ems(ems, targets)
        # handle a 3-part inventory refresh process
        # 1. collect inventory
        # 2. parse inventory
        # 3. save inventory
        log_header = format_ems_for_logging(ems)

        targets_with_inventory, _ = Benchmark.realtime_block(:collect_inventory_for_targets) do
          collect_inventory_for_targets(ems, targets)
        end

        until targets_with_inventory.empty?
          target, inventory = targets_with_inventory.shift

          _log.info "#{log_header} Refreshing target #{target.class} [#{target.name}] id [#{target.id}]..."
          hashes, _ = Benchmark.realtime_block(:parse_targeted_inventory) do
            parse_targeted_inventory(ems, target, inventory)
          end
          inventory = nil # clear to help GC

          Benchmark.realtime_block(:save_inventory) { save_inventory(ems, target, hashes) }
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

        provider_module = ManageIQ::Providers::Inflector.provider_module(ems.class).name

        targets_to_collectors = targets.each_with_object({}) do |target, memo|
          # expect collector at <provider>/Inventory/Collector/<target_name>
          memo[target] = "#{provider_module}::Inventory::Collector::#{target.class.name.demodulize}".safe_constantize
        end

        if targets_to_collectors.values.all?
          log_header = format_ems_for_logging(ems)
          targets_to_collectors.map do |target, collector_class|
            log_msg = "#{log_header} Inventory Collector for #{target.class} [#{target.try(:name)}] id: [#{target.id}]"
            _log.info "#{log_msg}..."
            collector = collector_class.new(ems, target)
            _log.info "#{log_msg}...Complete"
            [target, collector]
          end
        else
          # no collector for target available, fallback to full ems / manager refresh
          [[ems, nil]]
        end
      end

      def parse_targeted_inventory(ems, target, collector)
        # legacy refreshers collect inventory during the parse phase
        # new refreshers should override this method to parse inventory
        # TODO: remove this call after all refreshers support retrieving
        # inventory separate from parsing
        if collector.kind_of? ManagerRefresh::Inventory::Collector
          log_header = format_ems_for_logging(ems)
          _log.debug "#{log_header} Parsing inventory..."
          inventory_collections, = Benchmark.realtime_block(:parse_inventory) do
            provider_module = ManageIQ::Providers::Inflector.provider_module(ems.class).name
            inventory_target_class = "#{provider_module}::Inventory::Target::#{target.class.name.demodulize}".safe_constantize
            inventory_target = inventory_target_class.new(collector)

            parser_class = "#{provider_module}::Inventory::Parser::#{target.class.name.demodulize}".safe_constantize
            parser = parser_class.new

            i = ManagerRefresh::Inventory.new(inventory_target, collector, parser)
            i.inventory_collections
          end
          _log.debug "#{log_header} Parsing inventory...Complete"
          inventory_collections
        else
          hashes, = Benchmark.realtime_block(:parse_legacy_inventory) { parse_legacy_inventory(ems) }
          hashes
        end
      end

      def save_inventory(ems, target, hashes)
        EmsRefresh.save_ems_inventory(ems, hashes, target)
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
          next unless klass.respond_to? :post_refresh_ems
          _log.info "#{log_ems_target} Performing post-refresh operations for #{klass} instances..."
          klass.post_refresh_ems(ems.id, ems_refresh_start_time)
          _log.info "#{log_ems_target} Performing post-refresh operations for #{klass} instances...Complete"
        end
      end
    end
  end
end
