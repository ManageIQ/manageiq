require 'linux_admin'

module Vmdb
  module Appliance
    def self.VERSION
      @EVM_VERSION ||= File.read(File.join(File.expand_path(Rails.root), "VERSION")).strip
    end

    def self.BUILD
      @EVM_BUILD ||= get_build
    end

    def self.CODENAME
      "Hammer".freeze
    end

    def self.BANNER
      "#{self.PRODUCT_NAME} #{self.VERSION}, codename: #{self.CODENAME}"
    end

    def self.BUILD_NUMBER
      @EVM_BUILD_NUMBER ||= self.BUILD.nil? ? "N/A" : self.BUILD.split("-").last   # Grab the build number after the last hyphen
    end

    def self.log_config_on_startup
      Vmdb::Appliance.log_config(:startup => true)
      Vmdb::Appliance.log_server_identity
      Vmdb::Appliance.log_diagnostics
    end

    def self.PRODUCT_NAME
      ::Settings.product.name || I18n.t("product.name").freeze
    end

    def self.USER_AGENT
      "#{self.PRODUCT_NAME}/#{self.VERSION}".freeze
    end

    def self.log_config(*args)
      options = args.extract_options!
      fh = options[:logger] || $log
      init_msg = options[:startup] == true ? "* [VMDB] started on [#{Time.now}] *" : "* [VMDB] configuration *"
      border = "*" * init_msg.length
      fh.info(border)
      fh.info(init_msg)
      fh.info(border)

      fh.info("Version: #{self.VERSION}")
      fh.info("Build:   #{self.BUILD}")
      fh.info("Codename: #{self.CODENAME}")
      fh.info("RUBY Environment:  #{Object.const_defined?(:RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE} patchlevel #{RUBY_PATCHLEVEL}) [#{RUBY_PLATFORM}]"}")
      fh.info("RAILS Environment: #{Rails.env} version #{Rails.version}")

      fh.info("VMDB settings:")
      VMDBLogger.log_hashes(fh, ::Settings, :filter => Vmdb::Settings::PASSWORD_FIELDS)
      fh.info("VMDB settings END")
      fh.info("---")

      fh.info("DATABASE settings:")
      VMDBLogger.log_hashes(fh, ActiveRecord::Base.connection_config)
      fh.info("DATABASE settings END")
      fh.info("---")
    end

    def self.log_server_identity
      return unless MiqEnvironment::Command.is_appliance?
      # this is the request to overwrite a small file in the vmdb/log directory for each time the evm server is restarted.
      # the file must not be named ".log" or it will be removed by logrotate, and it must contain the Server GUID (by which the appliance is known in the vmdb,
      # the build identifier of the appliance as it is being started,  the appliance hostname and the name of the appliance as configured from our configuration screen.

      startup_fname = File.join(Rails.root, "log/last_startup.txt")
      FileUtils.rm_f(startup_fname) if File.exist?(startup_fname)
      begin
        startup = VMDBLogger.new(startup_fname)
        log_config(:logger => startup, :startup => true)
        startup.info("Server GUID: #{MiqServer.my_guid}")
        startup.info("Server Zone: #{MiqServer.my_zone}")
        startup.info("Server Role: #{MiqServer.my_role}")
        s = MiqServer.my_server
        region = MiqRegion.my_region
        startup.info("Server Region number: #{region.region}, name: #{region.name}") if region
        startup.info("Server EVM id and name: #{s.id} #{s.name}")

        startup.info("Currently assigned server roles:")
        s.assigned_server_roles(:include => :server_role).each { |r| startup.info("Role: #{r.server_role.name}, Priority: #{r.priority}") }

        issue = `cat /etc/issue 2> /dev/null` rescue nil
        startup.info("OS: #{issue.chomp}") unless issue.blank?

        network = get_network
        unless network.empty?
          startup.info("Network Information:")
          network.each { |k, v| startup.info("#{k}: #{v}") }
        end
        mem = `cat /proc/meminfo 2> /dev/null` rescue nil
        startup.info("System Memory Information:\n#{mem}") unless mem.blank?

        cpu = `cat /proc/cpuinfo 2> /dev/null` rescue nil
        startup.info("CPU Information:\n#{cpu}") unless cpu.blank?

        fstab = `cat /etc/fstab 2> /dev/null` rescue nil
        startup.info("fstab information:\n#{fstab}") unless fstab.blank?
      ensure
        startup.close rescue nil
      end
    end

    def self.log_diagnostics
      return unless MiqEnvironment::Command.is_appliance?

      init_diagnostics
      @diags.each do |diag|
        begin
          if diag[:cmd].kind_of?(Proc)
            res = diag[:cmd].call
          else
            res = AwesomeSpawn.run(diag[:cmd], :params => diag[:params]).output
          end
        rescue => e
          $log.warn("Diagnostics: [#{diag[:msg]}] command [#{diag[:cmd]}] failed with error [#{e}]")
          next  # go to next diagnostic command if this one blew up
        end
        $log.info("Diagnostics: [#{diag[:msg]}]\n#{res}") unless res.blank?
      end
    end

    def self.get_build
      build_file = File.join(File.expand_path(Rails.root), "BUILD")

      if File.exist?(build_file)
        build = File.read(build_file).strip.split("-").last
      else
        sha   = `git rev-parse --short HEAD`.chomp
        build = "unknown_#{sha}"
      end

      build
    end
    private_class_method :get_build

    def self.get_network
      retVal = {}
      eth0 = LinuxAdmin::NetworkInterface.new("eth0")
      retVal[:hostname]   = LinuxAdmin::Hosts.new.hostname
      retVal[:macaddress] = eth0.mac_address
      retVal[:ipaddress]  = eth0.address
      retVal[:netmask]    = eth0.netmask
      retVal[:gateway]    = eth0.gateway
      retVal[:primary_dns], retVal[:secondary_dns] = LinuxAdmin::Dns.new.nameservers

      retVal
    end
    private_class_method :get_network

    def self.installed_rpms
      File.open(log_dir.join("package_list_rpm.txt"), "a") do |file|
        file.puts "start: date time is: #{Time.now.utc}"
        LinuxAdmin::Rpm.list_installed.sort.each do |name, version|
          file.puts "#{name} #{version}"
        end
      end
    end
    private_class_method :installed_rpms

    def self.installed_gems
      File.open(log_dir.join("gem_list.txt"), "a") do |file|
        file.puts "start: date time is: #{Time.now.utc}"
        file.puts `gem list`
      end
    end
    private_class_method :installed_gems

    def self.log_dir
      Pathname.new("/var/www/miq/vmdb/log")
    end
    private_class_method :log_dir

    def self.init_diagnostics
      @diags ||= [
        {:cmd => "top",      :params => [:b, {:n => 1}],                              :msg => "Uptime, top processes, and memory usage"}, # batch mode - 1 iteration
        {:cmd => "pstree",   :params => [:a, :p],                                     :msg => "Process tree"},
        {:cmd => "df",       :params => [:all, :local, :human_readable, :print_type], :msg => "File system disk usage"},   # All including dummy fs, local, human readable, file system type
        {:cmd => "mount",                                                             :msg => "Mounted file systems"},
        {:cmd => "ifconfig", :params => [:a],                                         :msg => "Currently active interfaces"},  # -a display all interfaces which are currently available, even if down
        {:cmd => "route",                                                             :msg => "IP Routing table"},
        {:cmd => "netstat",  :params => [:interfaces, :all],                          :msg => "Network interface table"},
        {:cmd => "netstat",  :params => [:statistics],                                :msg => "Network statistics"},
        {:cmd => -> { File.read('/etc/hosts') if File.exist?('/etc/hosts') },         :msg => "Hosts file contents"},
        {:cmd => -> { File.read('/etc/fstab') if File.exist?('/etc/fstab') },         :msg => "FStab file contents"},
        {:cmd => -> { installed_gems },                                               :msg => "Installed Ruby Gems" },
        {:cmd => -> { installed_rpms },                                               :msg => "Installed RPMs" },
      ]
    end
    private_class_method :init_diagnostics
  end
end
