require 'optparse'
require 'ostruct'
require 'platform'
require 'yaml'
require 'log4r'
require 'extensions/miq-file'
require 'PlatformConfig'

require 'MiqTest'

$:.push("#{File.dirname(__FILE__)}/../../lib/util")
require 'miq-password'
require 'miq-system'
require 'miq-option-parser'

$log = Log4r::Logger['toplog']

class MiqHostConfig < MiqOptionParser::MiqCommandParser
    
    DEFAULTS = {
		:vmdbHost  => 'localhost',
		:vmdbPort  => '443',
		:readonly  => false,
		:log => {:level=>'info'},
		:wsListenPort => '1139',
		:heartbeat_frequency => 60,
		:scan_frequency => 0,
		:update_frequency => 0,
		:forceFleeceDefault => false,
		:webservices => {:consumer_protocol=>"https", :provider_protocol=>"https"},
    :miqhost_keep => 2
    }
    
	attr_accessor  :hostConfig

	def initialize
		super()
		self.handle_exceptions = true
		@hostConfig = OpenStruct.new(DEFAULTS.merge(readConfigFile))
		@hostConfig.ems = Hash.new if !@hostConfig.ems
		@hostConfig.emsEventMonitor = Array.new if !@hostConfig.emsEventMonitor

		self.program_name = $0
		@hostConfig.host_version = getVersion([2, 3, 0, 0], "NA")
		@hostConfig.build = @hostConfig.host_version[-1]
		self.program_version = @hostConfig.host_version[0..-2]
		
		@hostConfig.host_arch = MiqSystem.arch()
		@hostConfig.enableControl = false
		
		currentEmsName = nil

		self.option_parser = OptionParser.new do |opt|
			opt.separator "Global options:"
			#
			# The host and port of the vmdb application.
			# This is where the retrieved information is sent.
			#
			opt.on('-h=val', '--host=val', 'VMDB host') do |h|
			    @hostConfig.vmdbHost = h
			end
			opt.on('-p=val', '--port=val', 'VMDB port') do |p|
			    @hostConfig.vmdbPort = p
			end
			opt.on('-l=val', '--logfile=val', 'log file') do |f|
			    @hostConfig.logFile = f
			end
			opt.on('-r', '--readonly', 'only read operations are permitted on this host') do
			    @hostConfig.readonly = true
			end
			opt.on('--enable-control', 'enable \"Control\" capability on this host') do
			    @hostConfig.enableControl = true
			end
			opt.on('--ws-consumer-protocol=val', 'Protocol for consuming webservices (http/https)') do |p|
			    @hostConfig.webservices[:consumer_protocol] = p
			end
			#
			# Information required to access an external management system or systems.
			#
			opt.on('--emsname=val', 'the name of the external management system') do |n|
			    # puts "*** @hostConfig.ems[n] = #{@hostConfig.ems[n]}"
			    @hostConfig.ems[n] = Hash.new if !@hostConfig.ems[n]
			    currentEmsName = n
			end
			opt.on('--emstype=val', 'the type of external management system') do |t|
			    raise "--emsname must preceed --emstype, --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @hostConfig.ems[currentEmsName]['type'] = t
			end
			opt.on('--emshost=val', 'location of the external management system') do |h|
			    raise "--emsname must preceed --emstype, --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @hostConfig.ems[currentEmsName]['host'] = h
			end
			opt.on('--emsport=val', "the external management system's server port") do |p|
			    raise "--emsname must preceed --emstype, --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @hostConfig.ems[currentEmsName]['port'] = p
			end
			opt.on('--emsuser=val', "the user name needed to access the external management system") do |u|
			    raise "--emsname must preceed --emstype, --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @hostConfig.ems[currentEmsName]['user'] = u
			end
			opt.on('--emspassword=val', "the password needed to access the external management system") do |p|
			    raise "--emsname must preceed --emstype, --emshost, --emsport, --emsuser and --emspassword" if !currentEmsName
			    @hostConfig.ems[currentEmsName]['password'] = MiqPassword.encrypt(p)
			end
			opt.on('--emseventmonitor=val', 'the name of the external management system to monitor for events') do |n|
			    @hostConfig.emsEventMonitor << n unless @hostConfig.emsEventMonitor.include?(n)
			end
			opt.on('--emslocal=val', 'the name of the external management system used for local operations') do |n|
			    @hostConfig.emsLocal = n
			end
		end
		
		self.add_command(MiqHostInstall.new(@hostConfig))
		self.add_command(MiqHostShowConfig.new(@hostConfig))
		self.add_command(MiqHostDaemon.new(@hostConfig), true)
		self.add_command(MiqHostUninstall.new(@hostConfig))
		self.add_command(MiqHostStart.new(@hostConfig))
		self.add_command(MiqHostStop.new(@hostConfig))
		self.add_command(MiqHostAgentIn.new(@hostConfig))
		self.add_command(MiqHostAgentOut.new(@hostConfig))
		self.add_command(MiqHostBuild.new(@hostConfig))
		self.add_command(MiqHostCheck.new(@hostConfig))
		self.add_command(MiqRRS.new(@hostConfig))
		self.add_command(MiqHostTest.new(@hostConfig))
	end # def initialize
	
	def validateConfig
        errDetected = false
        
		# Test that all the config settings loaded are valid so we do not blowup
		# unexpectedly somewhere else.
		begin
			@hostConfig.marshal_dump.inspect
		rescue => err
            errDetected = true
			$log.error "Configuration setting error detected" if $log
			@hostConfig.marshal_dump.each_pair do |k,v|
				begin
					k;	v.inspect
				rescue => err
					$log.error "Error evaluating config parameter [#{k}].  Message:[#{err}]"  if $log
				end
			end
		end
        
        return errDetected
	end
	
	def readConfigFile
	    pc = PlatformConfig.new
	    
	    begin
			cfg = YAML.load_file(pc.files[:miqCfgFile])
	    rescue => err
	        cfg = Hash.new
    	end
    	
	    cfg[:miqHome]      = pc.files[:miqHome]         if !cfg[:miqHome]
	    cfg[:miqLogs]      = pc.files[:miqLogs]         if !cfg[:miqLogs]
	    cfg[:cfgFile]      = pc.files[:miqCfgFile]      if !cfg[:cfgFile]
	    cfg[:binDir]       = pc.files[:miqBinDir]       if !cfg[:binDir]
	    cfg[:libDir]       = pc.files[:miqLibDir]       if !cfg[:libDir]
        cfg[:dataDir]      = pc.files[:miqDataDir]      if !cfg[:dataDir]
	    cfg[:installedExe] = pc.files[:miqInstalledExe] if !cfg[:installedExe]

        # Remove unused config settings here
        cfg.delete(:logLevel)
        
	    return(cfg)
	end # def readConfigFile
	
	def self.writeConfig(config)
        #
        # Create the configuration file, based on the specified options.
        #
		File.open(config.cfgFile, 'w') { |cf| YAML.dump(config.marshal_dump, cf); cf.close}
	end

	def getVersion(default_version, default_build)
		version = File.read(File.join(File.dirname(__FILE__), "VERSION")).chomp.split('.') rescue default_version
		version << (File.read(File.join(File.dirname(__FILE__), "revision.svn")).chomp.split('-').last.to_i rescue default_build)
		return version
	end

end # class MiqHostConfig

class MiqHostInstall < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('install')
		self.short_desc = "Install #{$0} on this machine"
		@config = config
	end # def initialize

	def execute(args)
	    begin
			platform_config = PlatformConfig.new(@config)
				        
	        #
	        # Create the required directories.
	        #
	        makePath(@config.miqHome, 0755)    if !File.directory?(@config.miqHome)
	        makePath(@config.binDir,  0755)    if !File.directory?(@config.binDir)
	        makePath(@config.libDir,  0755)    if !File.directory?(@config.libDir)
	        makePath(@config.miqLogs, 0755)    if !File.directory?(@config.miqLogs)
            makePath(@config.dataDir, 0755)    if !File.directory?(@config.dataDir)
	        
	        #
	        # Copy the executable file of this command to the bin directory.
	        #
			if $miqExePath
				unless File.paths_equal?(@config.binDir, File.dirname($miqExePath))
					require 'fileutils'
					FileUtils.copy($miqExePath, @config.installedExe)
					# Restore File stats
					File.utime(File.atime($miqExePath), File.mtime($miqExePath), @config.installedExe)
				end
			end

			#
			# Create the configuration file, based on the specified options.
			#
			MiqHostConfig.writeConfig(@config)

			#
			# Perform platform dependant configurations.
			#
			platform_config.install if platform_config
	        
	        puts "Installation complete."
	        exit 0
	    rescue => err
	        $stderr.puts "#{$0}: #{err}"
	        exit 1
	    end
	end # def execute
	
private

    def makePath(path, mode)
        return if File.exists? path
        parentDir = File.dirname(path)
        makePath(parentDir, mode) if !File.exists? parentDir
        Dir.mkdir(path, mode)
    end
	
end # class MiqHostInstall

class MiqHostCheck < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('hostcheck')
		self.short_desc = "Check the host for possible installation problems"
		@config = config
	end # def initialize

	def execute(args)
	    platform_config = PlatformConfig.new(@config)
	    rv = platform_config.host_check(true)
	    exit rv
	end
	
end #class MiqHostCheckl

class MiqHostShowConfig < MiqOptionParser::MiqCommand

	def initialize(config)
		super('showconfig')
		self.short_desc = "Display current configuration"
		@config = config
	end # def initialize

	def execute(args)
	    YAML.dump(@config.marshal_dump, $stdout)
        exit 0
	end # def execute
	
end # class MiqHostShowConfig

class MiqHostDaemon < MiqOptionParser::MiqCommand

	def initialize(config)
		super('daemon')
		self.short_desc = "Run #{$0} in daemon mode"
		@config = config
	end # def initialize

	def execute(args)
        return  # Just fall through
	end # def execute

end # class MiqHostDaemon

class MiqHostUninstall < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('uninstall')
		self.short_desc = "Uninstall #{$0} on this machine"
		@config = config
	end # def initialize

	def execute(args)
	    platform_config = PlatformConfig.new(@config)

		#
		# Perform platform dependant configurations.
		#
		platform_config.uninstall

    require 'process_queue'
    # Setup $log so it is available when making webservice calls
    require 'miq-logger'
    $log = MIQLogger.get_log(nil)
    $log.level = Object.const_get($log.class.name.split('::').first)::FATAL
    begin
      puts "Attempting to unregister with server."
      ret = Manageiq::ProcessQueue.new(@config, "sync", {:timeout=>30}).parseCommand(["agentunregister", @config.hostId, "Performing [#{$0}] uninstall for guid [#{@config.hostId}]"])
    rescue
      ret = false
    end
    puts "Server unregister command was #{(ret == true ? "successful" : "unsuccessful")}."
		exit 0
	end
	
end # class MiqHostUninstall

class MiqHostStart < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('start')
		self.short_desc = "Start #{$0} on this machine"
		@config = config
	end # def initialize

	def execute(args)
	    begin
			platform_config = PlatformConfig.new(@config)
			platform_config.start_daemon
		rescue Win32::ServiceError => winErr
			puts winErr
		rescue
		end
		exit 0
	end
	
end

class MiqHostStop < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('stop')
		self.short_desc = "Stop #{$0} on this machine"
		@config = config
	end # def initialize

	def execute(args)
	    begin
			platform_config = PlatformConfig.new(@config)
			platform_config.stop_daemon
		rescue Win32::ServiceError => winErr
			puts winErr			
		rescue
		end
		exit 0
	end
	
end

class MiqHostBuild < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('build')
		self.short_desc = "Display the build number of the #{$0} agent"
		@config = config
	end # def initialize

	def execute(args)
        puts("Build: #{@config.build}")
        exit 0
	end
	
end # class MiqHostBuild

class MiqHostAgentIn < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('agentin')
		self.short_desc = "Configure incoming version of the #{$0} agent"
		@config = config
	end # def initialize

	def execute(args)
	    platform_config = PlatformConfig.new(@config)

		#
		# Perform platform dependant configurations.
		#
		platform_config.agent_in
		exit 0
	end
	
end # class MiqHostAgentIn

class MiqHostAgentOut < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('agentout')
		self.short_desc = "Un-configure outgoing version of the #{$0} agent"
		@config = config
	end # def initialize

	def execute(args)
	    platform_config = PlatformConfig.new(@config)

		#
		# Perform platform dependant configurations.
		#
		platform_config.agent_out
		exit 0
	end
	
end # class MiqHostAgentOut

class MiqRRS < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('rrs')
		@config = config
	end # def initialize

	def execute(args)
	    script = args.shift
	    exit 1 unless script
	    ARGV.replace(args)
	    $0 = script
	    load script
		exit 0
	end
	
end # class MiqHostTest

class MiqHostTest < MiqOptionParser::MiqCommand
    
	def initialize(config)
		super('test')
		self.short_desc = "Run test code"
		@config = config
	end # def initialize

	def execute(args)
	    require 'MiqTest'
	    MiqTest.test(args, @config)
		exit 0
	end
	
end # class MiqHostTest
