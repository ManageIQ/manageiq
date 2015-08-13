require 'platform'

class VMPlatformMount
    
    def initialize(dInfo, ost)
        $log.debug "Initializing VMPlatformMount" if $log
        @dInfo = dInfo
        @ost = ost
        
        if Platform::OS == :win32
			require "metadata/VMMount/VMPlatformMountWin"
			extend VMPlatformMountWin
		else
		    require "metadata/VMMount/VMPlatformMountLinux"
		    extend VMPlatformMountLinux
		end
		init
    end # def initialize
	
end # class VMPlatformMount
