class MiqThreadCtl
    
    @@quiesce  = false
    @@bailOut  = false
    @@waitExit = false
    @@quiesceByName = Hash.new
    @@bailOutByName = Hash.new
    @@threads = Array.new

    #
    # Exit all threads at a quiescent point.
    #
    def self.quiesceExit
        # a quiescent point is also a bail out point.
        Thread.current.exit if @@quiesce || @@bailOut
    end
    
    #
    # Return a flag indicating if threads should continue or bail out.
    #
    def self.continue?
        # a bail out point may not be a quiescent point.
        return !@@bailOut
    end
    
    #
    # Exit a given thread at a quiescent point.
    #
    def self.quiesceExitByName(name)
        # a quiescent point is also a bail out point.
        Thread.current.exit if @@quiesceByName[name] || @@bailOutByName[name] || @@quiesce || @@bailOut
    end
    
    #
    # Return a flag indicating if the given thread should continue or bail out.
    #
    def self.continueByName?(name)
        # a bail out point may not be a quiescent point.
        return !(@@bailOutByName[name] || @@bailOut)
    end
    
    #
    # Tell all threads they should exit at the next quiescent point.
    #
    def self.quiesce
        $log.debug "In MiqThreadCtl.quiesce" if $log
        @@quiesce = true
    end
    
    #
    # Tell all threads they should exit the next time they can.
    #
    def self.bailOut
        @@bailOut = true
    end
    
    #
    # Tell the given thread it should exit at the next quiescent point.
    #
    def self.quiesceByName(name)
        @@quiesceByName[name] = true
    end
    
    #
    # Tell the given thread it should exit the next time it can.
    #
    def self.bailOutByName(name)
        @@bailOutByName = true
    end
    
    #
    # Reset various flags.
    #
    
    def self.quiesceReset
        @@quiesce = false
    end
    
    def self.bailOutReset
        @@bailOut = false
    end
    
    def self.quiesceResetByName(name)
        @@quiesceByName[name] = false
    end
    
    def self.bailOutResetByName(name)
        @@bailOutByName[name] = false
    end
    
    #
    # Return an array of all the threads we control.
    #
    def self.threads
        return @@threads
    end
    
    def self.threads=(ta)
        @@threads = ta
    end
    
    #
    # Push a new thread onto our thread array.
    #
    def self.<<(t)
        @@threads << t
    end
    
    #
    # Wait for all of our threads to exit.
    #
    def self.waitThreads
        $log.debug "In MiqThreadCtl.waitThreads" if $log
        threads.each do |t|
            $log.info "waitThreads: #{t.to_s}" if $log
            t.join if t != Thread.current
            $log.info "waitThreads: #{t.to_s} exited" if $log
        end
    end
    
    #
    # Tell all threads to exit at their next quiescent point,
    # then wait for them to do so.
    #
    def self.quiesceWait
        $log.debug "MiqThreadCtl.quiesceWait calling quiesce" if $log
        quiesce
        $log.debug "MiqThreadCtl.quiesceWait calling waitThreads" if $log
        waitThreads
    end
    
    #
    # Tell all threads to exit the next time they can,
    # then wait for them to do so.
    #
    def self.bailOutWait
        bailOut
        waitThreads
    end
    
    def self.waitExit
			$log.debug "In MiqThreadCtl.waitExit" if $log
			while @@waitExit
				Thread.pass
			end
			$log.debug "Returning from MiqThreadCtl.waitExit" if $log
    end

    def self.exitHold
        $log.debug "In MiqThreadCtl.exitHold" if $log
        @@waitExit = true
    end
    
    def self.exitRelease
        $log.debug "In MiqThreadCtl.exitRelease" if $log
        @@waitExit = false
    end

    #
		# Return whether or not threads are being asked to exit
		#
		def self.exiting?
			return @@waitExit || @@quiesce || @@bailOut
		end
		
end #class MiqThreadCtl
