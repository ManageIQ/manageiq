require 'platform'

class VolMgrPlatformSupport
    
    def initialize(cfgFile, ost)
        $log.debug "Initializing VolMgrPlatformSupport" if $log
        @cfgFile = cfgFile
        @ost = ost
        
        if Platform::OS == :win32
			require "VolumeManager/VolMgrPlatformSupportWin"
			extend VolMgrPlatformSupportWin
		else
		    require "VolumeManager/VolMgrPlatformSupportLinux"
		    extend VolMgrPlatformSupportLinux
		end
		init
    end # def initialize
	
end # class VolMgrPlatformSupport
