module EmsRefresh::Refreshers
  class Ec2Refresher < BaseRefresher
    def refresh
      $log.info "MIQ(Ec2Refresher.refresh) Refreshing all targets..."

      @targets_by_ems_id.each do |ems_id, targets|
        # Get the ems object
        ems = @ems_by_ems_id[ems_id]

        log_header = "MIQ(Ec2Refresher.refresh) EMS: [#{ems.name}], id: [#{ems.id}]"
        $log.info "#{log_header} Refreshing targets for EMS: [#{ems.name}], id: [#{ems.id}]..."
        targets.each { |t| $log.info "#{log_header}   #{t.class} [#{t.name}] id [#{t.id}]" }

        start_time = Time.now

        $log.debug "#{log_header} Parsing EC2 inventory..."
        hashes = EmsRefresh::Parsers::Ec2.ems_inv_to_hashes(ems, refresher_options)
        $log.debug "#{log_header} Parsing EC2 inventory...Completed in #{Time.now - start_time} seconds"
        $log.debug "#{log_header} inv hashes:\n#{hashes.pretty_inspect}" if DEBUG_TRACE
        EmsRefresh.save_ems_inventory(ems, hashes)

        # Do any post-operations for this EMS
        [Vm].each do |klass|
          if klass.respond_to?(:post_refresh_ems)
            $log.info "#{log_header} Performing post-refresh operations for #{klass} instances..."
            klass.post_refresh_ems(ems_id, start_time)
            $log.info "#{log_header} Performing post-refresh operations for #{klass} instances...Complete"
          end
        end
      end

      $log.info "MIQ(Ec2Refresher.refresh) Refreshing all targets...Complete"
    end
  end
end
