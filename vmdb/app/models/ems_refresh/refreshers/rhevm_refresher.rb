module EmsRefresh::Refreshers
  class RhevmRefresher < BaseRefresher
    include RefresherRelatsMixin

    def refresh
      $log.info "MIQ(RhevmRefresher.refresh) Refreshing all targets..."

      @targets_by_ems_id.each do |ems_id, targets|
        # Get the ems object
        @ems = @ems_by_ems_id[ems_id]

        log_header = "MIQ(RhevmRefresher.refresh) EMS: [#{@ems.name}], id: [#{@ems.id}]"
        $log.info "#{log_header} Refreshing targets for EMS: [#{@ems.name}], id: [#{@ems.id}]..."
        targets.each { |t| $log.info "#{log_header}   #{t.class} [#{t.name}] id [#{t.id}]" }

        begin
          rhevm = @ems.rhevm_inventory
          raise "Invalid RHEV server ip address." if rhevm.api.nil?

          raw_ems_data = rhevm.refresh()
          if raw_ems_data.blank?
            $log.warn "#{log_header} No inventory data returned for EMS: [#{@ems.name}], id: [#{@ems.id}]..."
            next
          end

          @ems.api_version = rhevm.service.version_string

          refresh_complete = Time.now

          @ems.save

          hashes = EmsRefresh::Parsers::Rhevm.ems_inv_to_hashes(raw_ems_data)
          EmsRefresh.save_ems_inventory(@ems, hashes, targets[0])
        rescue => err
          $log.log_backtrace(err)
          $log.error("Unable to perform refresh for the following targets:" )
          targets.each do |target|
            target, filtered_data = *target if target.kind_of?(Array)
            $log.error("  #{target.class} [#{target.name}] id [#{target.id}]")
          end
          next
        end

        self.post_refresh_ems(refresh_complete)
      end

      $log.info "MIQ(RhevmRefresher.refresh) Refreshing all targets...Complete"
    end

    #TODO: move this and other common methods to a mixin
    def post_refresh_ems(start_time)
      log_header = "MIQ(VcRefresher.refresh) EMS: [#{@ems.name}], id: [#{@ems.id}]"
      [VmOrTemplate, Host].each do |klass|
        next unless klass.respond_to?(:post_refresh_ems)
        $log.info "#{log_header} Performing post-refresh operations for #{klass} instances..."
        klass.post_refresh_ems(@ems.id, start_time)
        $log.info "#{log_header} Performing post-refresh operations for #{klass} instances...Complete"
      end
    end
  end
end
