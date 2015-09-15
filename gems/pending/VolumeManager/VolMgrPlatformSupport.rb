require 'sys-uname'

class VolMgrPlatformSupport
    
    def initialize(cfgFile, ost)
        $log.debug "Initializing VolMgrPlatformSupport" if $log
        @cfgFile = cfgFile
        @ost = ost
        
        if Sys::Platform::OS == :windows
			require "VolumeManager/VolMgrPlatformSupportWin"
			extend VolMgrPlatformSupportWin
		else
		    require "VolumeManager/VolMgrPlatformSupportLinux"
		    extend VolMgrPlatformSupportLinux
		end
		init
    end # def initialize
	
end # class VolMgrPlatformSupport
