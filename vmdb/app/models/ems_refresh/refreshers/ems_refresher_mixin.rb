module EmsRefresh
  module Refreshers
    module EmsRefresherMixin
      def refresh
        log_header = "MIQ(#{self.class.name}.refresh)"
        $log.info "#{log_header} Refreshing all targets..."

        @targets_by_ems_id.each do |ems_id, targets|
          # Get the ems object
          ems = @ems_by_ems_id[ems_id]

          log_ems_target = "#{log_header} EMS: [#{ems.name}], id: [#{ems.id}]"
          $log.info "#{log_ems_target} Refreshing targets for EMS: [#{ems.name}], id: [#{ems.id}]..."
          targets.each { |t| $log.info "#{log_ems_target}   #{t.class} [#{t.name}] id [#{t.id}]" }

          ems_refresh_start_time = Time.now

          begin
            $log.debug "#{log_ems_target} Parsing #{refresher_type} inventory..."
            hashes = parse_inventory(ems, targets)
            $log.debug "#{log_ems_target} Parsing #{refresher_type} inventory..." \
                       "Completed in #{Time.now - ems_refresh_start_time} seconds"
            $log.debug "#{log_ems_target} inv hashes:\n#{hashes.pretty_inspect}" if self.class::DEBUG_TRACE

            if hashes.blank?
              # TODO: determine if this is "success" or "failed"
              $log.warn "#{log_header} No inventory data returned for EMS: [#{ems.name}], id: [#{ems.id}]..."
              next
            end
            save_inventory(ems, targets, hashes)
          rescue => e
            $log.error("#{log_ems_target} Refresh failed")
            $log.log_backtrace(e)
            $log.error("#{log_ems_target} Unable to perform refresh for the following targets:")
            targets.each do |target|
              target = target.first if target.is_a?(Array)
              $log.error(" --- #{target.class} [#{target.name}] id [#{target.id}]")
            end

            # record the failed status and skip post-processing
            ems.update_attributes(:last_refresh_error => e.to_s, :last_refresh_date => Time.now.utc)
            next
          ensure
            post_refresh_ems_cleanup(ems, targets)
          end

          ems.update_attributes(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
          post_refresh(ems, ems_refresh_start_time)
        end

        $log.info "#{log_header} Refreshing all targets...Complete"
      end

      def save_inventory(ems, _targets, hashes)
        EmsRefresh.save_ems_inventory(ems, hashes)
      end

      def post_refresh_ems_cleanup(_ems, _targets)
        # Clean up any resources opened during inventory collection
      end

      def post_process_refresh_classes
        # Return the list of classes that need post processing
        []
      end

      def post_refresh(ems, ems_refresh_start_time)
        log_header = "MIQ(#{self.class.name}.#{__method__})"
        log_ems_target = "#{log_header} EMS: [#{ems.name}], id: [#{ems.id}]"
        # Do any post-operations for this EMS
        post_process_refresh_classes.each do |klass|
          next unless klass.respond_to? :post_refresh_ems
          $log.info "#{log_ems_target} Performing post-refresh operations for #{klass} instances..."
          klass.post_refresh_ems(ems.id, ems_refresh_start_time)
          $log.info "#{log_ems_target} Performing post-refresh operations for #{klass} instances...Complete"
        end
      end
    end
  end
end
