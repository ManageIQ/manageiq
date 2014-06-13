class VmScanSchedule
    def self.start(host)
        # Get the scan frequency - Default to 1 day
        scan_frequency = host.cfg.scan_frequency.nil? ? 86400 : host.cfg.scan_frequency

        # Get the last scan time.  (Default to epoc if not set)
        last_scan = (host.cfg.auto_scan.nil? || host.cfg.auto_scan[:vm_last_scan_time].nil?) ? Time.at(0) : host.cfg.auto_scan[:vm_last_scan_time]

        # Setup task schedule
        first_run_in = scan_frequency - (Time.now - last_scan)

        # If we need to run the task wait 60 second before running
        first_run_in = 60 if first_run_in < 60

        host.scheduler.schedule_every("1d", :tags => ["vm", "metadata scan"], :first_in => "#{first_run_in}s") do |rufus_job|
            MiqThreadCtl.quiesceExit

            begin
                # Unschedule task if the refresh frequency is 0 or less
                if host.cfg.scan_frequency.nil? || host.cfg.scan_frequency <= 0
                    $log.debug "VM scan schedule is being disabled based on current frequency setting.  Scan Frequency:[#{host.cfg.scan_frequency.nil? ? "nil" : host.cfg.scan_frequency}]"
                    rufus_job.params[:dont_reschedule] = true
                else
                    ret = host.runSyncTask(["getvms", "-f"])
                    MiqThreadCtl.quiesceExit
                    eval(ret).each {|vm| host.miqScanMetadata(vm[:location])}

                    host.cfg.auto_scan ||= {}
                    host.cfg.auto_scan[:vm_last_scan_time] = Time.now.utc
                    # Make sure we record this value
                    MiqHostConfig.writeConfig(host.cfg)

                    rufus_job.params[:every] = "#{host.cfg.scan_frequency}s"
                end
            rescue => err
                $log.error "VmScanSchedule: [#{err}]"
                $log.debug "VmScanSchedule: [#{err.backtrace}]"
            end
        end
    end
end
