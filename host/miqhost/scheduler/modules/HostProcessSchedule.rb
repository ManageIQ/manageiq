require 'process_queue'
require 'platform'

class HostProcessSchedule
    def self.start(host)
        last_log_time = Time.at(0)

        return nil unless Platform::IMPL == :linux

        host.scheduler.schedule_every("30m", :tags => ["host", "stats", "process"], :first_in => host.heartbeat_freq) do
            MiqThreadCtl.quiesceExit

            # Log only once if we fail to perform a heartbeat
            if !host.stats[:heartbeat][:total].zero? || last_log_time.to_i == 0
              if $log
                diags = [{:cmd => "top -b -n 1", :msg =>"Uptime, top processes, and memory usage"}]
                diags.each do  |diag|
                  begin
                    if diag[:evaluate?]
                      res = eval(diag[:cmd])
                    else
                      res = `#{diag[:cmd]}`
                      raise "Command yielded no data" if res.blank?
                    end
                  rescue =>e
                    $log.warn("Diagnostics: [#{diag[:msg]}] command [#{diag[:cmd]}] failed with error [#{e.to_s}]")
                    next  # go to next diagnostic command if this one blew up
                  end
                  $log.info("Diagnostics: [#{diag[:msg]}]\n#{res}") unless res.blank?
                end
              end

              # Reset last_log_time
              last_log_time = Time.now
            end
        end
    end
end
