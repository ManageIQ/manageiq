module VdiRefresh::Refreshers
  class PowershellRefresherBase
    def self.refresh(targets)
      self.new(targets).refresh
    end

    def initialize(targets)
      log_header = "MIQ(#{self.class.name}.initialize)"
      # Store ActiveRecord objects, grouped by VdiFarm id
      @farms_by_farm_id = {}
      @targets_by_farm_id = targets.each_with_object(Hash.new { |h, k| h[k] = Array.new }) do |t, h|
        farm = t.kind_of?(VdiFarm) ? t : t.vdi_farm
        if farm.nil?
          $log.warn "#{log_header} Unable to perform refresh for #{t.class} [#{t.name}] id [#{t.id}], since it is not on an VdiFarm."
          next
        end

        @farms_by_farm_id[farm.id] ||= farm
        h[farm.id] << t
      end
    end

    def refresh
      $log.info "MIQ(#{self.class.name}.refresh) Queueing refresh for all targets..."

      @targets_by_farm_id.each do |farm_id, targets|
        # Get the VdiFarm object
        @farm = @farms_by_farm_id[farm_id]

        log_header = "MIQ(#{self.class.name}.refresh) VDI Farm: [#{@farm.name}], id: [#{@farm.id}]"
        $log.info "#{log_header} Queueing refresh targets for VDI Farm: [#{@farm.name}], id: [#{@farm.id}]..."
        targets.each { |t| $log.info "#{log_header}   #{t.class} [#{t.name}] id [#{t.id}]" }

        begin
          queue_options = {:class_name => @farm.class.name, :method_name => "process_inventory_async", :instance_id => @farm.id, :zone => MiqServer.my_zone}
          self.active_proxy.powershell_command_async(self.class.inventory_class.inv_ps_script, 'xml', nil, queue_options)
        rescue => err
          if err.kind_of?(MiqException::Error)
            $log.error "#{log_header} #{err}"
          else
            $log.log_backtrace(err)
          end
          $log.error("Unable to perform refresh for the following targets:" )
          targets.each do |target|
            target, filtered_data = *target if target.kind_of?(Array)
            $log.error("  #{target.class} [#{target.name}] id [#{target.id}]")
          end
          next
        end
      end

      $log.info "MIQ(#{self.class.name}.refresh) Queueing refresh for all targets...Complete"
    end

    def active_proxy
      ps_proxy = @farm.active_proxy
      if ps_proxy.blank?
        if @farm.miq_proxies.blank?
          raise MiqException::Error, "No SmartProxy configured for VDI Farm <#{@farm.name}>"
        else
          raise MiqException::Error, "No active SmartProxy found"
        end
      end
      return ps_proxy
    end
  end
end
