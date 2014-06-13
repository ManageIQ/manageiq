$:.push("#{File.dirname(__FILE__)}/modules")

class HostScheduler
	MODDIR = File.join(File.dirname(__FILE__), "modules")
	
	def self.startScheduledTasks(host)
		Dir.foreach(MODDIR) do |pmf|
			next if !File.fnmatch('?*Schedule.rb', pmf)
			pmod = pmf.chomp(".rb")
			require pmod
            begin
                eval(pmod).start(host)
            rescue => e
                $log.error "Host Scheduler: #{e}"
                $log.debug "Host Scheduler: #{e.backtrace.join("\n")}"
            end
		end
		return(nil)
	end
end
