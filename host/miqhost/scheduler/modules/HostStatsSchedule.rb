require 'process_queue'

class HostStatsSchedule
    def self.start(host)
        last_log_time = Time.at(0)
        process_count = 0

        host.scheduler.schedule_every(host.heartbeat_freq, :tags => ["host", "stats"], :first_in => host.heartbeat_freq) do
            MiqThreadCtl.quiesceExit

            # Log only once if we fail to perform a heartbeat
            if !host.stats[:heartbeat][:total].zero? || last_log_time.to_i == 0
              # Do a little logic so we do not constantly log stats if nothing is happening
              # If we have not logged anything for 10 mins (600 sec) force it.
              if (Time.now - last_log_time > 600) || (process_count != Manageiq::ProcessQueue.total)
                host.logStats()

                # Reset last_log_time
               last_log_time = Time.now
              end

              # Set the process count and add one for the known heartbeat that should occur.
              process_count = Manageiq::ProcessQueue.total + 1
            end
        end
    end
end
