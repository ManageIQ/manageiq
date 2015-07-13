require 'rubygems'
require 'platform'

class VolMgrPlatformSupport
    
    def initialize(cfgFile, ost)
        $log.debug "Initializing VolMgrPlatformSupport" if $log
        @cfgFile = cfgFile
        @ost = ost
        
        if Platform::OS == :win32
			require "VolMgrPlatformSupportWin"
			extend VolMgrPlatformSupportWin
		else
		    require "VolMgrPlatformSupportLinux"
		    extend VolMgrPlatformSupportLinux
		end
		init
    end # def initialize
	
end # class VolMgrPlatformSupport
