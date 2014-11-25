module Vmdb
  module Appliance
    def self.VERSION
      @EVM_VERSION ||= File.read(File.join(File.expand_path(Rails.root), "VERSION")).strip
    end

    def self.BUILD
      @EVM_BUILD ||= get_build
    end

    def self.BUILD_NUMBER
      @EVM_BUILD_NUMBER ||= self.BUILD.nil? ? "N/A" : self.BUILD.split("-").last   # Grab the build number after the last hyphen
    end

    def self.log_config_on_startup
      Vmdb::Appliance.log_config(:startup => true)
      Vmdb::Appliance.log_server_identity
      Vmdb::Appliance.log_diagnostics
    end

    def self.log_config(*args)
      options = args.extract_options!
      fh = options[:logger] || $log
      init_msg = options[:startup] == true ? "* [VMDB] started on [#{Time.now}] *" : "* [VMDB] configuration *"
      border = "*" * init_msg.length
      fh.info border
      fh.info init_msg
      fh.info border

      fh.info "Version: #{self.VERSION}"
      fh.info "Build:   #{self.BUILD}"
      fh.info "RUBY Environment:  #{Object.const_defined?(:RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE} patchlevel #{RUBY_PATCHLEVEL}) [#{RUBY_PLATFORM}]"}"
      fh.info "RAILS Environment: #{Rails.env} version #{Rails.version}"

      fh.info "Soap4r version: #{SOAP::VERSION}  Parser: [#{XSD::XMLParser.create_parser(self, {}).class}]" rescue nil

      fh.info "VMDB settings:"
      vmdb_config = VMDB::Config.new("vmdb").config
      VMDBLogger.log_hashes(fh, vmdb_config, :filter => Vmdb::ConfigurationEncoder::PASSWORD_FIELDS)
      fh.info "VMDB settings END"
      fh.info "---"

      fh.info "DATABASE settings:"
      db_config = VMDB::Config.new("database").config[Rails.env.to_sym]
      VMDBLogger.log_hashes(fh, db_config)
      fh.info "DATABASE settings END"
      fh.info "---"
    end

    def self.log_server_identity
      return unless MiqEnvironment::Command.is_appliance?
      #this is the request to overwrite a small file in the vmdb/log directory for each time the evm server is restarted.
      #the file must not be named ".log" or it will be removed by logrotate, and it must contain the Server GUID (by which the appliance is known in the vmdb,
      #the build identifier of the appliance as it is being started,  the appliance hostname and the name of the appliance as configured from our configuration screen.

      startup_fname = File.join(Rails.root, "log/last_startup.txt")
      FileUtils.rm_f(startup_fname) if File.exist?(startup_fname)
      begin
        startup = VMDBLogger.new(startup_fname)
        log_config(:logger => startup, :startup => true)
        startup.info "Server GUID: #{MiqServer.my_guid}"
        startup.info "Server Zone: #{MiqServer.my_zone}"
        startup.info "Server Role: #{MiqServer.my_role}"
        s = MiqServer.my_server
        region = MiqRegion.my_region
        startup.info "Server Region number: #{region.region}, name: #{region.name}" if region
        startup.info "Server EVM id and name: #{s.id} #{s.name}"

        startup.info "Currently assigned server roles:"
        s.assigned_server_roles(:include => :server_role).each { |r| startup.info "Role: #{r.server_role.name}, Priority: #{r.priority}" }

        issue = `cat /etc/issue 2> /dev/null` rescue nil
        startup.info "OS: #{issue.chomp}" unless issue.blank?

        network = get_network
        unless network.empty?
          startup.info "Network Information:"
          network.each { |k, v| startup.info "#{k}: #{v}" }
        end
        mem = `cat /proc/meminfo 2> /dev/null` rescue nil
        startup.info "System Memory Information:\n#{mem}" unless mem.blank?

        cpu = `cat /proc/cpuinfo 2> /dev/null` rescue nil
        startup.info "CPU Information:\n#{cpu}" unless cpu.blank?

        fstab = `cat /etc/fstab 2> /dev/null` rescue nil
        startup.info "fstab information:\n#{fstab}" unless fstab.blank?

        vars = ""
        ENV.each { |k, v| vars << "#{k} = #{v}\n"}
        startup.info "Environment Variables: \n#{vars}" unless vars.blank?
      ensure
        startup.close rescue nil
      end
    end

    def self.log_diagnostics
      return unless MiqEnvironment::Command.is_appliance?

      init_diagnostics
      # TODO:  Add pinging of gateways and Database
      #      pings =""
      #      gateways = `/sbin/route -n | awk '{ if ($4 ~ /G/) print $2; }'`.split("\n").collect {|g| pings << `ping -c 5 #{g}`}
      # TODO: Make this method executable as a scheduled queue item

      # execute or evaluate each diagnostic command
      @diags.each do |diag|
        begin
          if diag[:evaluate?]
            res = eval(diag[:cmd])
          else
            res = `#{diag[:cmd]}`
          end
        rescue => e
          $log.warn("Diagnostics: [#{diag[:msg]}] command [#{diag[:cmd]}] failed with error [#{e}]")
          next  # go to next diagnostic command if this one blew up
        end
        $log.info("Diagnostics: [#{diag[:msg]}]\n#{res}") unless res.blank?
      end

      vars = ""
      ENV.each { |k, v| vars << "#{k} = #{v}\n"}
      $log.info "Environment Variables: \n#{vars}" unless vars.blank?
    end

    private

    def self.get_build
      build_file = File.join(File.expand_path(Rails.root), "BUILD")

      if File.exist?(build_file)
        build = File.read(build_file).strip.split("-").last
      else
        date  = Time.now.strftime("%Y%m%d%H%M%S")
        sha   = `git rev-parse --short HEAD`.chomp
        build = "#{date}_#{sha}"
      end

      build
    end

    def self.get_network
      retVal = {}
      miqnet = "/bin/miqnet.sh"

      if File.exist?(miqnet)
        # Make a call to the virtual appliance to get the network information
        cmd     = "#{miqnet} -GET"
        netinfo = `#{cmd}`
        raise "Unable to execute command: #{cmd}" if netinfo.nil?
        netinfo = netinfo.split

        [:hostname, :macaddress, :ipaddress, :netmask, :gateway, :primary_dns, :secondary_dns].each do |type|
          retVal[type] = netinfo.shift
        end
      end

      retVal
    end

    def self.init_diagnostics
      log_dir = "/var/www/miq/vmdb/log"
      gem_log = File.join(log_dir, "gem_list.txt")
      ven_gem_log = File.join(log_dir, "vendor_gems.txt")
      rpm_log = File.join(log_dir, "package_list_rpm.txt")
      dpkg_log = File.join(log_dir, "package_list_dpkg.txt")

      @diags ||= [
        {:cmd => "top -b -n 1", :msg =>"Uptime, top processes, and memory usage"}, # batch mode - once
        {:cmd => "pstree -ap", :msg => "Process tree"},
        {:cmd => "df -alhT", :msg => "File system disk usage"},   # All including dummy fs, local, human readable, file system type
        {:cmd => "mount", :msg => "Mounted file systems"},
        {:cmd => "ifconfig -a", :msg => "Currently active interfaces"},
        {:cmd => "route", :msg => "IP Routing table"},
        {:cmd => "netstat -i -a", :msg => "Network interface table"},
        {:cmd => "netstat -s", :msg => "Network statistics"},
        {:cmd => "File.open('/etc/hosts','r'){|f| f.read} if File.exist?('/etc/hosts')", :evaluate? => true, :msg => "Hosts file contents"},
        {:cmd => "File.open('/etc/fstab','r'){|f| f.read} if File.exist?('/etc/fstab')", :evaluate? => true, :msg => "Fstab file contents"},
        {:cmd => "echo start: date time is: #{Time.now.utc} >> #{gem_log}; gem list > #{gem_log}"},
        {:cmd => "echo start: date time is: #{Time.now.utc} >> #{ven_gem_log}; ls -1 vendor/gems > #{ven_gem_log}"},
        {:cmd => "echo start: date time is: #{Time.now.utc} >> #{rpm_log}; rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' |sort -k 1  > #{rpm_log} 2> /dev/null"},
        {:cmd => "echo start: date time is: #{Time.now.utc} >> #{dpkg_log}; dpkg -l > #{dpkg_log} 2> /dev/null"}
      ]
    end
  end
end
