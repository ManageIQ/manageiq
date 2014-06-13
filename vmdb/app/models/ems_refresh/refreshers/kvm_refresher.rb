$:.push("#{File.dirname(__FILE__)}/../../../../../lib/kvm")
require 'MiqKvmInventory'

module EmsRefresh::Refreshers
  class KvmRefresher < BaseRefresher
    include RefresherRelatsMixin

    def refresh
      $log.info "MIQ(KvmRefresher.refresh) Refreshing all targets..."

      @targets_by_ems_id.each do |ems_id, targets|
        # Get the ems object
        @ems = @ems_by_ems_id[ems_id]

        log_header = "MIQ(KvmRefresher.refresh) EMS: [#{@ems.name}], id: [#{@ems.id}]"
        $log.info "#{log_header} Refreshing targets for EMS: [#{@ems.name}], id: [#{@ems.id}]..."
        targets.each { |t| $log.info "#{log_header}   #{t.class} [#{t.name}] id [#{t.id}]" }

        begin
          kvm = nil
          kvm = MiqKvmInventory.new(@ems.ipaddress, *@ems.auth_user_pwd())
          hashes = kvm.refresh()
          if hashes.blank?
            $log.warn "#{log_header} No inventory data returned for EMS: [#{@ems.name}], id: [#{@ems.id}]..."
            next
          end

          EmsRefresh.save_ems_inventory(@ems, hashes, targets[0])
        rescue => err
          $log.log_backtrace(err)
          $log.error("Unable to perform refresh for the following targets:" )
          targets.each do |target|
            target, filtered_data = *target if target.kind_of?(Array)
            $log.error("  #{target.class} [#{target.name}] id [#{target.id}]")
          end
          next
        ensure
          kvm.disconnect if kvm
        end
      end

      $log.info "MIQ(KvmRefresher.refresh) Refreshing all targets...Complete"
    end
  end
end
