$:.push("#{File.dirname(__FILE__)}/../../util")

require 'UpdateAgent'
require 'MiqTimer'

module InstallLinux
    
    VMWARE_RELEASE          = "/etc/vmware-release"
    VMPERL                  = "/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/VMware/VmPerl.pm"
    ESX_CONF                = "/etc/vmware/esx.conf"
    HOSTS                   = "/etc/hosts"
    RESOLV_CONF             = "/etc/resolv.conf"
    
    VMWARE_CMD              = "/usr/bin/vmware-cmd"
    VMWARE                  = "/usr/bin/vmware"
    ESX_FIREWALL_CMD        = "/usr/sbin/esxcfg-firewall"
    ESX_SERVICE_CMD         = "/sbin/service"
    
    ESX_VMWARE_INIT         = "/etc/init.d/mgmt-vmware"
    ESX_VMWARE_INIT_SAVE    = "/etc/init.d/mgmt-vmware.miqsave"
    ESX_VMWARE_INIT_TMP     = "/etc/init.d/mgmt-vmware.miqtmp"
    ESX_LIB_HOOKS           = "miq_lib_hooks.so"
    
    ACTIVATE_SCRIPT  = "linux_agent_activate"
    INIT_D_DIR       = "etc/init.d"
    INIT_D_FILE      = "miqhostd"
    RC_DIR           = "/etc"
    START_LINK       = "S90miqhost"
    KILL_LINK        = "K10miqhost"
    START_RL         = [ 2, 3, 4, 5 ]
    KILL_RL          = [ 0, 1, 6 ]
	
	def init()
	    @files = nil
	    @initScript = File.join("/", INIT_D_DIR, INIT_D_FILE)
	end

	def install
	    #
	    # Create hard link from miqhost to miq-cmd.
	    #
	    system("rm -f #{files[:miqInstalledCmd]}") if File.exists? files[:miqInstalledCmd]
	    system("ln #{@cfg.installedExe} #{files[:miqInstalledCmd]}")
	    
	    logputs(true, "InstallLinux: Can't complete install, miqExtDir is not set") if $miqExtDir.nil?
	    return if $miqExtDir.nil?
	    
	    #
	    # Copy the miq init script to /etc/init.d
	    #
	    src  = File.join($miqExtDir, "host", "miqhost", INIT_D_DIR, INIT_D_FILE)
	    dest = File.join("/", INIT_D_DIR, INIT_D_FILE)
	    require 'fileutils'
	    FileUtils.copy(src, dest)
	    
	    #
	    # Link the miq init script to the required files in /etc/rc?.d
	    #
	    src = dest
	    START_RL.each { |rl| system("ln -fs #{src} #{File.join(RC_DIR, "rc#{rl}.d", START_LINK)}") }
	    KILL_RL.each  { |rl| system("ln -fs #{src} #{File.join(RC_DIR, "rc#{rl}.d", KILL_LINK)}") }
	    
	    #
	    # If we're not configured for Control features, don't install the miq hooks.
	    #
	    return if !@cfg.enableControl
	    
	    #
	    # Install the miq hooks into vmware-hostd, so we can trap the starting of VMs.
	    #
	    if File.exists?(ESX_VMWARE_INIT)
	        #
	        # Stop vmware-hostd.
	        # We need to stop it before updating the hooks.
	        #
	        system("#{ESX_VMWARE_INIT} stop 2>&1 > /dev/null")
	        
	        #
	        # Extract the hook library.
	        #
	        srcHooks = File.join($miqExtDir, "lib", "esx_lib_hooks", ESX_LIB_HOOKS)
	        hookLib  = File.join(files[:miqLibDir], ESX_LIB_HOOKS)
	        FileUtils.copy(srcHooks, hookLib)
	        
	        #
	        # If the hooks are already active, we're done.
	        #
	        if system("grep LD_PRELOAD #{ESX_VMWARE_INIT} 2>&1 > /dev/null")
	            #
    	        # Restart vmware-hostd.
    	        #
    	        system("#{ESX_VMWARE_INIT} start 2>&1 > /dev/null")
	            return
	        end
	              
	        #
	        # Create a temp file containing the maodified init.d script.
	        #
	        File.delete(ESX_VMWARE_INIT_TMP) if File.exists?(ESX_VMWARE_INIT_TMP)
	        system("sed -e \"1a LD_PRELOAD=#{hookLib}\" -e \"1a export LD_PRELOAD\" #{ESX_VMWARE_INIT} > #{ESX_VMWARE_INIT_TMP}")
	        
	        #
	        # Save the original init.d script and replace it with the modified version.
	        #
	        File.rename(ESX_VMWARE_INIT, ESX_VMWARE_INIT_SAVE) if !File.exists?(ESX_VMWARE_INIT_SAVE)
	        File.rename(ESX_VMWARE_INIT_TMP, ESX_VMWARE_INIT) if !File.exists?(ESX_VMWARE_INIT)
	        system("chmod 744 #{ESX_VMWARE_INIT}")
	        
	        #
	        # Restart vmware-hostd.
	        #
	        system("#{ESX_VMWARE_INIT} start 2>&1 > /dev/null")
	    end
	end # def install

	def uninstall
	    delete_daemon
	end
	
	def start_daemon
	    system("#{@initScript} start")
	end
	
	def stop_daemon
    	system("nohup #{@initScript} stop 2>&1 > /dev/null &")
	end
	
	def restart_daemon
	    logFile = File.join(files[:miqLogs], "miqhostRestart.log")
	    cmd = "nohup #{@initScript} restart 2>&1 >> #{logFile} &"
	    $log.debug "restart_daemon calling: #{cmd}"
	    system("date >> #{logFile}")
	    system("echo \"#{cmd}\" >> #{logFile}")
    	system(cmd)
	end
	
	def delete_daemon
	    #
	    # Remove hard link from miqhost to miq-cmd.
	    #
	    system("rm -f #{files[:miqInstalledCmd]}")
	    
	    #
	    # Remove the miq init script from /etc/init.d
	    #
	    system("rm -f #{File.join("/", INIT_D_DIR, INIT_D_FILE)}")
	    
	    #
	    # Remove the links to the miq init script from the /etc/rc?.d directories
	    #
	    START_RL.each { |rl| system("rm -f #{File.join(RC_DIR, "rc#{rl}.d", START_LINK)}") }
	    KILL_RL.each  { |rl| system("rm -f #{File.join(RC_DIR, "rc#{rl}.d", KILL_LINK)}") }
	    
	    #
	    # Remove the miq hooks from vmware-hostd.
	    #
	    if File.exists?(ESX_VMWARE_INIT_SAVE)
	        #
	        # Stop vmware-hostd.
	        #
	        system("#{ESX_VMWARE_INIT} stop 2>&1 > /dev/null")
	        #
	        # Restore the original init.d script.
	        #
	        File.delete(ESX_VMWARE_INIT) if File.exists?(ESX_VMWARE_INIT)
	        File.rename(ESX_VMWARE_INIT_SAVE, ESX_VMWARE_INIT)
	        #
	        # Restart vmware-hostd.
	        #
	        system("#{ESX_VMWARE_INIT} start 2>&1 > /dev/null")
	    end
	end # def delete_daemon
	
	def agent_out
	    delete_daemon
	    cacheFile = Manageiq::AgentMgmt.getAgentBuildPath(files[:miqBinDir], @cfg.build)
	    system("ln #{$miqExePath} #{cacheFile}") if !File.exists? cacheFile
	    system("rm -f #{$miqExePath}")
	end
	
	def agent_in
	    cacheFile = Manageiq::AgentMgmt.getAgentBuildPath(files[:miqBinDir], @cfg.build)
	    #
	    # We must be running from the cache file for this version.
	    #
	    return if File.basename(cacheFile) != File.basename($miqExePath)
	    
	    system("rm -f #{@cfg.installedExe}") if File.exists? @cfg.installedExe
	    system("ln #{cacheFile} #{@cfg.installedExe}")
        
        # Create the data directory if it does not already exist
        Dir.mkdir(@cfg.dataDir, 0755) if !File.directory?(@cfg.dataDir)
        
	    install
	end
	
	def agent_activate(props)
	    activateScript = File.join(files[:miqBinDir], ACTIVATE_SCRIPT)
	    if !File.exists?(activateScript) && $miqExtDir
	        $log.info "agent_activate: creating #{activateScript}"
	        srcScript = File.join($miqExtDir, ACTIVATE_SCRIPT)
	        require 'fileutils'
	        FileUtils.copy(srcScript, activateScript)
	        system("chmod 755 #{activateScript}")
	    end
	    logFile = File.join(files[:miqLogs], "miqhostActivate.log")
	    newAgent = Manageiq::AgentMgmt.getAgentPath(files[:miqBinDir], props)
	    system("chmod 755 #{newAgent}")
	    system("nohup #{activateScript} #{$miqExePath} #{newAgent} 2>&1 >> #{logFile} &")
	end
	
	def starting
	    return unless File.executable?(ESX_FIREWALL_CMD)
	    system("#{ESX_FIREWALL_CMD} --openPort #{@cfg.wsListenPort},tcp,in,\"miqhost\" 2>&1 > /dev/null")
	    system("#{ESX_FIREWALL_CMD} --openPort #{@cfg.vmdbPort},tcp,out,\"miqhost\" 2>&1 > /dev/null")
	    system("#{ESX_SERVICE_CMD} xinetd restart 2>&1 > /dev/null")
	end
	
	def stopping
	    return unless File.executable?(ESX_FIREWALL_CMD)
	    system("#{ESX_FIREWALL_CMD} --closePort #{@cfg.wsListenPort},tcp,in 2>&1 > /dev/null")
	    system("#{ESX_FIREWALL_CMD} --closePort #{@cfg.vmdbPort},tcp,out,\"miqhost\" 2>&1 > /dev/null")
	    system("#{ESX_SERVICE_CMD} xinetd restart 2>&1 > /dev/null")
	end
	
	def host_check(toStdout=false)
	    errors = 0
	    
	    logputs toStdout
	    logputs toStdout, "****** Host Check Start ******"
	    logputs toStdout
	    
	    #
	    # Get and log the host name.
	    #
	    hostName = `uname -n`.chomp
	    logputs toStdout, "Host name: #{hostName}"
	    
	    #
	    # Get and log the IP address.
	    #
	    ifcstr = `ifconfig | sed -e "/^vswif0/,/^$/p" -e d | grep "inet addr:"`
        ipaddr = /^.*inet addr:([^\s]+)\s/.match(ifcstr)
        ipaddr = ipaddr[1] if ipaddr
        ipaddr = "unknown" unless ipaddr
	    logputs toStdout, "IP Address: #{ipaddr}"
	    
	    #
	    # Log the current date and time.
	    #
	    logputs toStdout, "Host date and time:"
	    cmdout = `date`
	    logputs toStdout, "    #{cmdout}"
	    logputs toStdout
	    
	    #
	    # Check forward network name resolution.
	    #
	    if hostName && !hostName.empty?
	        et = MiqTimer.time do
	            cmdout = `nslookup -debug #{hostName} | grep "internet address = "`
	        end
	        if !cmdout || cmdout.empty?
	            logputs toStdout, "Forward name lookup failed in #{et} seconds."
	            errors += 1
	        else
	            ipaddr2 = /^.*internet address = ([^\s]+)$/.match(cmdout)
	            ipaddr2 = ipaddr2[1] if ipaddr2
	            ipaddr2 = "unknown" unless ipaddr2
	            logputs toStdout, "Forward name lookup succeeded in #{et} seconds. Returned IP address = #{ipaddr2}"
	        end
	    else
	        logputs toStdout, "Skipping forward name lookup check: host name not available."
	    end
	    
	    #
	    # Check reverse network name resolution.
	    #
	    if ipaddr && !ipaddr.empty?
	        et = MiqTimer.time do
	            cmdout = `nslookup -debug #{ipaddr} | grep "name = "`
	        end
	        if !cmdout || cmdout.empty?
	            logputs toStdout, "Reverse name lookup failed in #{et} seconds."
	            errors += 1
	        else
	            hostName2 = /^.*name = ([^\s]+)$/.match(cmdout)
	            hostName2 = hostName2[1] if hostName2
	            hostName2 = "unknown" unless hostName2
	            logputs toStdout, "Reverse name lookup succeeded in #{et} seconds. Returned host name = #{hostName2}"
	        end
	    else
	        logputs toStdout, "Skipping reverse name lookup check: IP address not available."
	    end
	    logputs toStdout
	    
	    #
	    # Log the contents of the "hosts" file.
	    #
	    errors += check_and_cat(toStdout, HOSTS)
	    
	    #
	    # Log the contents of the "resolv.conf" file.
	    #
	    errors += check_and_cat(toStdout, RESOLV_CONF)
	    
	    #
	    # Check for VMware release information on ESX.
	    #
	    errors += check_and_cat(toStdout, VMWARE_RELEASE)
	    
	    #
	    # Check for the existence of the "vmware" command.
	    # If found, display its version information.
	    #
	    errors += check_and_exec(toStdout, "#{VMWARE} -v")
	    
	    #
	    # Check for the required VMware Perl modules.
	    #
	    errors += check(toStdout, VMPERL)
	    
	    #
	    # Check for the existence of the "vmware-cmd" command.
	    # If found, use it to display registered VMs.
	    #
	    errors += check_and_exec(toStdout, "#{VMWARE_CMD} -l")
	    
	    #
	    # Check for the existence of the "esxcfg-firewall" command.
	    # If found, use it to display the current filewall settings.
	    #
	    errors += check_and_exec(toStdout, "#{ESX_FIREWALL_CMD} -q")
	    
	    #
	    # Check for the existence of the "esx.conf" file.
	    # If found, display the amount of configured service console memory.
	    #
	    if File.exists? ESX_CONF
	        logputs toStdout, "File: #{ESX_CONF} found."
	        cmd = "grep memSize #{ESX_CONF}"
	        cmdout = `#{cmd}`
	        logputs toStdout, "Service console memory: #{cmdout}"
	    else
	        logputs toStdout, "File: #{ESX_CONF} not found."
	        errors += 1
	    end
	    logputs toStdout
	    
	    #
	    # Log the total number of possible problems.
	    #
	    logputs toStdout, "Total errors: #{errors}"
	    
	    logputs toStdout
	    logputs toStdout, "****** Host Check End ******"
	    logputs toStdout
        
        return errors
	end
  
  def capabilities
    caps = {:vixDisk => false}
    begin
      require 'VixDiskLib'
      caps[:vixDisk] = true
    rescue Exception => err
      # It is ok if we hit an error, it just means the library is not available to load.
    end

    return caps
  end
	
	def files
	    return @files if @files
	    
	    @files                    = Hash.new
	    @files[:miqHome]          = "/opt/miq"
        @files[:miqLogs]          = "/var/opt/miq/log"
        @files[:miqDataDir]       = "/var/opt/miq/data"
        @files[:miqCfgFile]       = File.join(@files[:miqHome],   "miqhost.yaml")
        @files[:miqBinDir]        = File.join(@files[:miqHome],   "bin")
        @files[:miqLibDir]        = File.join(@files[:miqHome],   "lib")
        @files[:miqInstalledExe]  = File.join(@files[:miqBinDir], "miqhost")
        @files[:miqInstalledCmd]  = File.join(@files[:miqBinDir], "miq-cmd")
        
        return @files
	end

	def remoteInstall(settings)
		return false
	end


	private
	
	def logputs(toStdout, msg="")
	    puts msg         if toStdout
	    $log.summary msg if $log
	end
	
	def check(toStdout, file)
	    rv = 0
	    if File.exists? file
	        logputs toStdout, "File: #{file} found."
	    else
	        logputs toStdout, "File: #{file} not found."
	        rv = 1
	    end
	    logputs toStdout
	    return rv
	end
	
	def check_and_cat(toStdout, file)
	    rv = 0
        if File.exists? file
            logputs toStdout, "** Begin file: \"#{file}\" contents:"
            logputs toStdout, IO.read(file)
            logputs toStdout, "** End file: \"#{file}\" contents"
        else
            logputs toStdout, "File: #{file} not found."
            rv = 1
        end
    	logputs toStdout
    	return rv
    end
    
    def check_and_exec(toStdout, cmd)
        rv = 0
        cmdFile = cmd.split[0]
        
	    if File.exists? cmdFile
	        logputs toStdout, "** Begin command: \"#{cmd}\" output:"
	        logputs toStdout, `#{cmd}`
	        logputs toStdout, "** End command: \"#{cmd}\" output:"
	    else
	        logputs toStdout, "File: #{cmdFile} not found."
	        rv = 1
	    end
	    logputs toStdout
	    return rv
    end
end
