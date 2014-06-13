$:.push("#{File.dirname(__FILE__)}/../../lib/util")

require 'MiqThreadCtl'

module EmsEventMonitor

    def monitorEmsEvents()
        @cfg.emsEventMonitor.each do | emsName |
            $log.info "Starting event monitor for: #{emsName}"
            hostId = getHostId()
            MiqThreadCtl << Thread.new do
                runSyncTask(["monitoremsevents", emsName, hostId])
            end
            sleep 5
        end if @cfg.emsEventMonitor
    end
    
end

