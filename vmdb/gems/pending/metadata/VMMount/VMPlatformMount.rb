require 'rubygems'
require 'platform'

class VMPlatformMount
    
    def initialize(dInfo, ost)
        $log.debug "Initializing VMPlatformMount" if $log
        @dInfo = dInfo
        @ost = ost
        
        if Platform::OS == :win32
			require "VMPlatformMountWin"
			extend VMPlatformMountWin
		else
		    require "VMPlatformMountLinux"
		    extend VMPlatformMountLinux
		end
		init
    end # def initialize
	
end # class VMPlatformMount
