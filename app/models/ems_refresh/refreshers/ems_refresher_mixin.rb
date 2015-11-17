module EmsRefresh
  module Refreshers
    module EmsRefresherMixin
      def refresh
        _log.info "Refreshing all targets..."

        @targets_by_ems_id.each do |ems_id, targets|
          # Get the ems object
          ems = @ems_by_ems_id[ems_id]

          log_ems_target = "EMS: [#{ems.name}], id: [#{ems.id}]"
          _log.info "#{log_ems_target} Refreshing targets for EMS: [#{ems.name}], id: [#{ems.id}]..."
          targets.each { |t| _log.info "#{log_ems_target}   #{t.class} [#{t.name}] id [#{t.id}]" }

          ems_refresh_start_time = Time.now

          begin
            _log.debug "#{log_ems_target} Parsing #{refresher_type} inventory..."
            hashes = parse_inventory(ems, targets)
            _log.debug "#{log_ems_target} Parsing #{refresher_type} inventory..." \
                       "Completed in #{Time.now - ems_refresh_start_time} seconds"
            _log.debug "#{log_ems_target} inv hashes:\n#{hashes.pretty_inspect}" if self.class::DEBUG_TRACE

            if hashes.blank?
              # TODO: determine if this is "success" or "failed"
              _log.warn "No inventory data returned for EMS: [#{ems.name}], id: [#{ems.id}]..."
              next
            end
            save_inventory(ems, targets, hashes)
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
            next
          ensure
            post_refresh_ems_cleanup(ems, targets)
          end

          ems.update_attributes(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
          post_refresh(ems, ems_refresh_start_time)
        end

        _log.info "Refreshing all targets...Complete"
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
        log_ems_target = "EMS: [#{ems.name}], id: [#{ems.id}]"
        # Do any post-operations for this EMS
        post_process_refresh_classes.each do |klass|
          next unless klass.respond_to? :post_refresh_ems
          _log.info "#{log_ems_target} Performing post-refresh operations for #{klass} instances..."
          klass.post_refresh_ems(ems.id, ems_refresh_start_time)
          _log.info "#{log_ems_target} Performing post-refresh operations for #{klass} instances...Complete"
        end
      end

      def fetch_entities(client, entities)
        h = {}
        entities.each do |entity|
          begin
            h[entity[:name].singularize] = client.send("get_" << entity[:name])
          rescue KubeException => e
            if entity[:default].nil?
              throw e
            else
              $log.error("Unexpected Exception during refresh: #{e}")
              h[entity[:name].singularize] = entity[:default]
            end
          end
        end
        h
      end
    end
  end
end
