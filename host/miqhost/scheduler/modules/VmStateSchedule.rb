class VmStateSchedule
    def self.start(host)
        # Setup the task schedule (default internal is 10 min, but the task will reschedule itself on the first pass.
        host.scheduler.schedule_every("10m", :tags => ["vm", "state refresh"], :first_in => "30s") do |rufus_job|
            MiqThreadCtl.quiesceExit

            begin
                # Unschedule task if the refresh frequency is 0 or less
                if host.cfg.vmstate_refresh_frequency.nil? || host.cfg.vmstate_refresh_frequency <= 0
                    $log.info "VM state fresh schedule is being disabled based on current frequency setting.  State Refresh Frequency:[#{host.cfg.vmstate_refresh_frequency.nil? ? "nil" : host.cfg.vmstate_refresh_frequency}]"
                    rufus_job.params[:dont_reschedule] = true
                else
                    # Only send data if the heartbeat is active
                    if host.heartbeat_alive?
                        host.miqSendVMState(nil)
                        host.cfg.auto_scan ||= {}
                        host.cfg.auto_scan[:vm_last_vm_state_scan_time] = Time.now.utc
                        rufus_job.params[:every] = "#{host.cfg.vmstate_refresh_frequency}s"
                    else
                        # If the heartbeat is not active at the time we are called, reset the task
                        # frequency to check after the next heartbeat
                        rufus_job.params[:every] = "#{host.heartbeat_freq}s"
                    end
                end
            rescue => err
                $log.error "VmStateSchedule: [#{err}]"
                $log.debug "VmStateSchedule: [#{err.backtrace}]"
            end
        end
    end
end
