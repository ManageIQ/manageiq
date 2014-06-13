
module MiqVimVdlConnectionMod
	
	#
	# Return a VixDiskLib connection object for the same server that VIM is connected to.
	#
	def vdlConnection
		require 'VixDiskLib'
        VixDiskLib.init(lambda { |s| $vim_log.info  "VMware(VixDiskLib): #{s}" },
                        lambda { |s| $vim_log.warn  "VMware(VixDiskLib): #{s}" },
                        lambda { |s| $vim_log.error "VMware(VixDiskLib): #{s}" })
		$vim_log.info "MiqVimMod.vdlConnection: #{@server}"
		vdlConnection = VixDiskLib.connect(:serverName => server,
		                                       :port       => 902,
		                                       :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
		                                       :userName   => username,
		                                       :password   => password)
		return vdlConnection
    end
    
    def closeVdlConnection(connection)
		$vim_log.info "MiqVimMod.closeVdlConnection: #{connection.serverName}"
		connection.disconnect
    end

end # module MiqVimVdlConnectionMod


module MiqVimVdlVcConnectionMod
	
	#
	# Return a VixDiskLib connection object for the VC server that VIM is connected to.
	# The connection is specific to this VM, and should be closed by the caller when it
	# has finished accessing the VM's disk files.
	#
	def vdlVcConnection
	    require 'VixDiskLib'
	
        VixDiskLib.init(lambda { |s| $vim_log.info  "VMware(VixDiskLib): #{s}" },
                        lambda { |s| $vim_log.warn  "VMware(VixDiskLib): #{s}" },
                        lambda { |s| $vim_log.error "VMware(VixDiskLib): #{s}" })
	    
		$vim_log.info "MiqVimVmMod.vdlVcConnection: #{invObj.server}"
	    VixDiskLib.connect(:serverName => invObj.server,
	                       :vmxSpec    => vixVmxSpec,
                           :port       => 902,
                           :credType   => VixDiskLib_raw::VIXDISKLIB_CRED_UID,
                           :userName   => invObj.username,
                           :password   => invObj.password)
    end

end # module MiqVimVdlVcConnectionMod
