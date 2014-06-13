
$:.push("#{File.dirname(__FILE__)}/../../../../../lib/Scvmm")
require 'MiqScvmmInventory'


module EmsRefresh::Refreshers
  class ScvmmRefresher < BaseRefresher
    def refresh
      log_header = "MIQ(#{self.class.name}.refresh)"
      $log.info "#{log_header} Refreshing all targets..."

      @targets_by_ems_id.each do |ems_id, targets|
        # Get the ems object
        ems = @ems_by_ems_id[ems_id]

        log_ems_target = "#{log_header} EMS: [#{ems.name}], id: [#{ems.id}]"
        $log.info "#{log_ems_target} Refreshing targets for EMS: [#{ems.name}], id: [#{ems.id}]..."
        targets.each { |t| $log.info "#{log_ems_target}   #{t.class} [#{t.name}] id [#{t.id}]" }

        start_time = Time.now

        $log.debug "#{log_ems_target} Parsing Scvmm inventory..."
        hashes = EmsRefresh::Parsers::Scvmm.ems_inv_to_hashes(ems, refresher_options)
        $log.debug "#{log_ems_target} Parsing Scvmm inventory...Completed in #{Time.now - start_time} seconds"
        $log.debug "#{log_ems_target} inv hashes:\n#{hashes.pretty_inspect}" if DEBUG_TRACE
        EmsRefresh.save_ems_inventory(ems, hashes)

        # Do any post-operations for this EMS
        [Vm].each do |klass|
          if klass.respond_to?(:post_refresh_ems)
            $log.info "#{log_ems_target} Performing post-refresh operations for #{klass} instances..."
            klass.post_refresh_ems(ems_id, start_time)
            $log.info "#{log_ems_target} Performing post-refresh operations for #{klass} instances...Complete"
          end
        end
      end

      $log.info "#{log_header} Refreshing all targets...Complete"
    end
  end
end
