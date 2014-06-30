module VMDB
  class Config
    @@hostwsdisabled = false
    @@wscontactwith = "ipaddress"
    @@wsnameresolution = false
    @@listening_port = 80
    @@wstimeout = 120
    @@sync_cfile = Sync.new()
    @@cached_configs = {}

    require_relative 'configuration_encoder'

    def self.clone_auth_for_log(auth)
      log_auth = auth.deep_clone
      [:bind_pwd, :amazon_secret].each do |key|
        log_auth[key] = '********' if log_auth.has_key?(key)
        if log_auth.has_key?(:user_proxies)
          log_auth[:user_proxies].each do |p|
            p[key] = '********' if p.has_key?(key)
          end
        end
      end
      log_auth
    end

    def self.invalidate(name)
      @@cached_configs.delete(name)
    end

    def self.invalidate_all
      invalidate_configuration_source
      @@cached_configs.clear
    end

    def self.invalidate_configuration_source
      @use_db_for_config = nil
    end

    def self.configuration_source(name)
      # database.yml is always read from the filesystem
      return :filesystem if name == 'database'

      # Once we determine the model is loaded, the tables exist, and the server is known, let's the use the DB
      return :database if @use_db_for_config

      log_header = "MIQ(Config.configuration_source)"

      unless VMDB::model_loaded?(:Configuration)
        $log.debug "#{log_header} Using filesystem configurations since Configuration model is not loaded" if $log
        return :filesystem
      end

      # Once the model is loaded, establish a connection or return an existing connection
      conn = ActiveRecord::Base.connection rescue nil
      unless conn && ActiveRecord::Base.connected?
        $log.debug "#{log_header} Using filesystem configurations since DB is not connected" if $log
        return :filesystem
      end

      tables = conn.tables
      ['miq_servers', 'configurations'].each do |t|
        unless tables.include?(t)
          $log.warn("#{log_header} Using filesystem configurations since [#{t}] table does not exist!") if $log
          return :filesystem
        end
      end

      if MiqServer.my_server.nil?
        $log.warn("#{log_header} Using filesystem configurations until MiqServer is known.  This may be resolved by next server startup. ") if $log
        return :filesystem
      end

      # Now that the DB is to be used, invalidate the cached configs from the filesystem
      invalidate_all
      @use_db_for_config = true
      $log.debug("#{log_header} Using database configurations") if $log
      :database
    end

    attr_reader   :name, :configuration_source
    attr_accessor :config
    attr_accessor :errors

    def initialize(name, autoload = true)
      @name = name
      @config = @errors = nil
      return unless autoload

      log_header = "MIQ(Config.initialize)"
      _root = File.join(File.expand_path(Rails.root))

      @cfile = File.join(_root, "config/#{name}.yml")
      @ctmpl = File.join(_root, "config/#{name}.tmpl.yml")
      @cfile_db = @cfile + ".db"
      @config_mtime = @template_mtime = nil

      @configuration_source = self.class.configuration_source(@name)
      if self.cached_config_valid?
        @config = @@cached_configs[name][:data].deep_clone
      else
        $log.debug "#{log_header} #{@@cached_configs.has_key?(name) && !@@cached_configs[name][:mtime].nil? ? "Rel" : "L"}oading configuration file for \"#{name}\"" if $log

        @@sync_cfile.synchronize(:EX) do
          if configuration_source == :filesystem && 'database' == name && !File.exists?(@cfile) && File.exists?(@ctmpl)
            puts("MIQ(Config.initialize) Creating #{@cfile} from #{@ctmpl}")
            FileUtils.copy(@ctmpl, @cfile)
          end
        end
        defaults = self.retrieve_config(:tmpl)
        current =  self.retrieve_config(:yml)
        raise "MIQ(Config.initialize) unable to locate configuration file or template file for \"#{name}\"" if current.nil? && defaults.nil?

        # if the database is the source of the configuration, create or update db record and rename the config file if an override was used
        $log.debug("#{log_header} Source of configuration: #{configuration_source}") if $log
        if configuration_source == :database
          server = MiqServer.my_server
          raise "MiqServer.my_server cannot be nil" if server.nil?
          @db_record = server.configurations.find_by_typ(@name)

          conf = current

          if @db_record.nil? && conf.nil?
            conf = defaults
            $log.info("#{log_header} [#{@name}] - Using template to populate DB since settings were not found") if $log
          end

          @db_record = Configuration.create_or_update(server, conf, name) unless conf.blank?

          @@sync_cfile.synchronize(:EX) do
            # rename the config file if we already created the db_record and the file exists
            if File.exists?(@cfile) && !@db_record.nil?
              File.rename(@cfile, @cfile_db)
              $log.info("#{log_header} [#{@name}] Config in DB will now be used.  Renamed file to [#{@cfile_db}]") if $log
            end
          end
          # use the record from the db
          current = @db_record.settings if @db_record
        end
        current = Config.apply_defaults(current, defaults) unless current.nil? || defaults.nil?
        current = defaults if current.nil?

        @config = current
        self.update_cache_metadata
      end

      @config_mtime   = @@cached_configs[@name][:mtime]
      @template_mtime = @@cached_configs[@name][:mtime_tmpl]

      return @config
    end

    def self.load_config_file(fname)
      data = IO.read(fname) if File.exists?(fname)
      Vmdb::ConfigurationEncoder.load(data)
    end

    def retrieve_config(typ = :yml)
      fname = typ == :yml ? @cfile : @ctmpl
      self.class.load_config_file(fname)
    end

    def normalize_time(input)
      # Return a time object in UTC... if mtime is nil or mtime is not parseable, return nil
      Time.parse(input.to_s).utc rescue nil unless input.nil?
    end

    def config_mtime_from_db
      #log_header = "MIQ(Config.config_mtime_from_db) [#{@name}]"
      server = MiqServer.my_server(true)
      return if server.nil?

      conf = server.configurations.find_by_typ(@name, :select => "updated_on")
      return if conf.nil?

      mtime = conf.updated_on
      #$log.debug("#{log_header} Config mtime retrieved from db [#{mtime}]") unless $log.nil? || mtime.nil?
      self.normalize_time(mtime) if mtime
    end

    def config_mtime_from_file(typ)
      #log_header = "MIQ(Config.config_mtime_from_file) [#{@name}] type: [#{typ}]"
      fname = typ == :yml ? @cfile : @ctmpl
      mtime = File.mtime(fname) if File.exists?(fname)
      #$log.debug("#{log_header} Config mtime retrieved from file [#{mtime}]") unless $log.nil? || mtime.nil?
      self.normalize_time(mtime)
    end

    def template_configuration
      self.class.load_config_file(@ctmpl)
    end

    def merge_from_template(*args)
      args << template_configuration.fetch_path(*args)
      self.config.store_path(*args)
      self.save
    end

    def merge_from_template_if_missing(*args)
      self.merge_from_template(*args) if self.config.fetch_path(*args).nil?
    end


    def get(section, key=nil)
      # get(section, key) -> value
      # get(section) -> hash of section values
      return nil if !self.config.keys.include?(section)

      if key.nil?
        self.config[section]
      else
        self.config[section][key]
      end
    end

    def set(section, key=nil, value=nil)
      # set(section, key, value)
      # set(section, hash)
      # set(hash)
      if key.nil?
        # set(hash) -> section holds a hash of the entire configuration
        self.config = section
      else
        if value.nil?
          # set(section, hash) -> key holds the hash for specified section
          self.config[section] = key
        else
          # set(section, key, value)
          self.config[section][key] = value
        end
      end
    end

    # Get the worker settings converted to bytes, seconds, etc.
    def get_worker_setting(klass, setting = nil)
      self._get_worker_setting(klass, setting, false)
    end

    # Get the worker settings as they are in the yaml: 1.seconds, 1, etc.
    def get_raw_worker_setting(klass, setting = nil)
      self._get_worker_setting(klass, setting, true)
    end

    def _get_worker_setting(klass, setting = nil, raw = false)
      # get a specific setting.... if provided
      klass = Object.const_get(klass) unless klass.class == Class
      full_settings = klass.worker_settings(:config => self.config, :raw => raw)
      return full_settings if setting.nil?

      return full_settings.fetch_path(*setting) if setting.kind_of?(Array)
      full_settings.fetch_path(setting)
    end

    def set_worker_setting!(klass, setting, value)
      klass = Object.const_get(klass) unless klass.class == Class

      # find the key for the class and set the value
      keys = klass.path_to_my_worker_settings.dup
      keys.unshift(:workers)
      keys += setting.to_miq_a
      self.config.store_path(keys, value)
    end

    def save
      log_header = "MIQ(Config.save)"
      raise "configuration invalid, see errors for details" if !self.validate

      begin
        Vmdb::ConfigurationEncoder.validate!(@config)
      rescue SyntaxError
        raise "Syntax error while parsing new configuration!"
      end

      svr = MiqServer.my_server(true)
      case configuration_source
      when :database
        @db_record = Configuration.create_or_update(svr, @config, @name)
        self.save_file(@cfile_db)
        $log.info("#{log_header} Saved Config [#{@name}] from database in file: [#{@cfile_db}]") if $log
      when :filesystem
        self.save_file(@cfile_db)
        $log.info("#{log_header} Saved Config [#{@name}] in file: [#{@cfile_db}]") if $log
      end
      self.update_cache_metadata

      self.activate

      svr.reset if svr
    end

    def save_file(filename)
      @@sync_cfile.synchronize(:EX) do
        comments = Config.get_comments(filename) # Save comments from cfg file before deleting.
        comments = Config.get_comments(@ctmpl) if comments == "" # Try the template file if none in the cfg file.
        File.delete(filename) if File.exists?(filename)
        #File.open(@cfile, "w") {|f| YAML.dump(Config.stringify(@config), f)}
        fd = File.open(filename, "w")
        fd.write(comments.join) if comments.kind_of?(Array)
        Vmdb::ConfigurationEncoder.dump(@config, fd)
        fd.close
      end
    end

    def stale?
      return true unless cached_config_valid?
      return true if (@@cached_configs.fetch_path(@name, :mtime)      != @config_mtime)
      return true if (@@cached_configs.fetch_path(@name, :mtime_tmpl) != @template_mtime)
      return false
    end

    def cached_config_valid?
      return false unless @@cached_configs.has_key?(@name)

      log_header = "MIQ(Config.cached_config_valid?)"
      config_mtime = self.config_mtime_from_file(:yml)
      db_config_mtime = self.config_mtime_from_db if configuration_source == :database

      # if the database is the configuration_source, check if the DB record needs to be created or if the config mtime is newer than the DB mtime
      if configuration_source == :database
        if db_config_mtime.nil?
          $log.debug("#{log_header} Cache Miss because DB mtime does not exist and the DB is the configuration source #{@name}") if $log
          return false
        elsif !config_mtime.nil? && config_mtime > db_config_mtime
          $log.debug("#{log_header} Cache Miss because config mtime [#{config_mtime}] is newer than DB mtime [#{db_config_mtime}] for #{@name}") if $log
          return false
        end
      end

      config_mtime = db_config_mtime unless db_config_mtime.nil?

      template_mtime = self.config_mtime_from_file(:tmpl)
      msg = "@name: [#{@name}], mtime/cached: [#{config_mtime}/#{@@cached_configs[@name][:mtime]}], mtime_tmpl/cached: [#{template_mtime}/#{@@cached_configs[@name][:mtime_tmpl]}]"
      if (@@cached_configs[@name][:mtime] == config_mtime) && (@@cached_configs[@name][:mtime_tmpl] == template_mtime)
        return true
      else
        $log.debug("#{log_header} Cache Miss: #{msg}") if $log
        return false
      end
      false
    end

    def update_cache_metadata
      @@cached_configs[@name] = {} if @@cached_configs[@name].blank?
      @@cached_configs[@name][:data] = @config.deep_clone
      @@cached_configs[@name][:mtime] = configuration_source == :database ? self.config_mtime_from_db : self.config_mtime_from_file(:yml)
      @@cached_configs[@name][:mtime_tmpl] =  self.config_mtime_from_file(:tmpl)

      @config_mtime   = @@cached_configs[@name][:mtime]
      @template_mtime = @@cached_configs[@name][:mtime_tmpl]

      #TODO: the log_limit method should really register a callback that the update_cache method then loops over
      $log.on_config_change(@@cached_configs[@name][:data]) if $log.respond_to?(:on_config_change)
    end

    def validate
      @errors = {}
      valid = true
      @config.each_key {|k|
        if Config.respond_to?(k.to_s)
          ost = OpenStruct.new(@config[k].stringify_keys)
          section_valid, errors = Config.send(k.to_s, ost, "validate")

          if !section_valid
            errors.each {|e|
              key, msg = e
              @errors[[k, key].join("_")] = msg
            }
            valid = false
          end
        end
      }
      valid
    end

    def ldap_verify
      @errors = {}

      auth = @config[:authentication]
      begin
        ldap = MiqLdap.new(
          :host => auth[:ldaphost],
          :port => auth[:ldapport],
          :mode => auth[:mode]
        )
        ldap.ldap.auth(auth[:bind_dn], auth[:bind_pwd]) if auth[:ldap_role] == true
        result = ldap.ldap.bind
      rescue Exception => err
        result = false
        @errors[[:authentication, auth[:mode]].join("_")] = err.message
      else
        @errors[[:authentication, auth[:mode]].join("_")] = "Authentication failed" unless result
      end

      result
    end

    def amazon_verify
      @errors = {}

      auth = @config[:authentication]
      begin
        amazon_auth = AmazonAuth.new(:auth=>auth)
        result = amazon_auth.admin_connect
      rescue Exception => err
        result = false
        @errors[[:authentication, auth[:mode]].join("_")] = err.message
      else
        @errors[[:authentication, auth[:mode]].join("_")] = "Authentication failed" unless result
      end

      result
    end

    def activate
      raise "configuration invalid, see errors for details" if !self.validate

      @config.each_key {|k|
        if Config.respond_to?(k.to_s)
          ost = OpenStruct.new(@config[k].stringify_keys)
          Config.send(k.to_s, ost)
        end
      }
    end

    def self.refresh_configs
      log_header = "MIQ(Config.refresh_configs)"

      # Refresh all cached configs
      @@cached_configs.each_key do |k|
        Config.new(k.to_s)
        $log.debug("#{log_header} [#{k.inspect}] config refreshed") if $log
      end
    end

    def self.VERSION
      @@EVM_VERSION ||= File.read(File.join(File.expand_path(Rails.root), "VERSION")).strip
    end

    def self.BUILD
      @@EVM_BUILD ||= Config.get_build
    end

    def self.BUILD_NUMBER
      @@EVM_BUILD_NUMBER ||= Config.BUILD.nil? ? "N/A" : Config.BUILD.split("-").last   # Grab the build number after the last hyphen
    end

    def self.SOAP_VERSION
      @@SOAP_VERSION ||= SOAP::VERSION
    end

    def self.PARSER
      @@PARSER ||= XSD::XMLParser.create_parser(self, {}).class rescue nil
    end

    def self.product?(name)
      product = Config.new("vmdb").config[:product]
      case name.downcase
      when "insight"
        return true
      when "control"
        return true if product[:control] || product[:automate]
      when "automate"
        return true if product[:automate]
      end
      false
    end

    def self.schema_update
      $log.info("MIQ(config-schema_update) updating database schema from version [#{SchemaMigration.schema_version}] to version [#{SchemaMigration.latest_migration}]")
      begin
        result = `rake db:migrate --trace`
      rescue => err
        $log.error("MIQ(config-schema_update) update failed, #{err}")
        return
      end

      if $?.exitstatus == 0
        result.split("\n").each {|m| $log.info("MIQ(config-schema_update) #{m}")}
      else
        result.split("\n").each {|m| $log.error("MIQ(config-schema_update) #{m}")}
      end
    end

    def self.db_schema_up_to_date?
      begin
        migrations = SchemaMigration.missing_db_migrations
        files      = SchemaMigration.missing_file_migrations
        db_ver     = SchemaMigration.schema_version
      rescue => err
        return [false, err]
      end

      return [false, "database schema is not up to date.  Schema version is [#{db_ver}].  Missing migrations: [#{migrations.join(", ")}]",
        "database should be migrated to the latest version"] unless migrations.empty?
      return [false, "database schema is from a newer version of the product and may be incompatible.  Schema version is [#{db_ver}].  Missing files: [#{files.join(", ")}]",
        "appliance should be updated to match database version"] unless files.empty?

      return [true, "database schema version #{db_ver} is up to date"]
    end

    private

    def self.get_build
      build_file = File.join(File.expand_path(Rails.root), "BUILD")

      if File.exists?(build_file)
        build = File.read(build_file).strip.split("-").last
      else
        date  = Time.now.strftime("%Y%m%d%H%M%S")
        sha   = `git rev-parse --short HEAD`.chomp
        build = "#{date}_#{sha}"
      end

      build
    end

    def self.log_config(*args)
      options = args.extract_options!
      fh = options[:logger] || $log
      init_msg = options[:startup] == true ? "* [VMDB] started on [#{Time.now}] *" : "* [VMDB] configuration *"
      border = "*" * init_msg.length
      fh.info border
      fh.info init_msg
      fh.info border

      fh.info "Version: #{Config.VERSION}"
      fh.info "Build:   #{Config.BUILD}"
      fh.info "RUBY Environment:  #{Object.const_defined?(:RUBY_DESCRIPTION) ? RUBY_DESCRIPTION : "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE} patchlevel #{RUBY_PATCHLEVEL}) [#{RUBY_PLATFORM}]"}"
      fh.info "RAILS Environment: #{Rails.env} version #{Rails.version}"
      fh.info "Soap4r version: #{Config.SOAP_VERSION}  Parser: [#{Config.PARSER}]" rescue nil

      fh.info "VMDB settings:"
      vmdb_config = Config.new("vmdb").config
      VMDBLogger.log_hashes(fh, vmdb_config, :filter => "bind_pwd")

      line_limit = vmdb_config[:log][:line_limit].to_i
      if line_limit > 0
        line_limit = 132 if line_limit < 132
        fh.info "Log line is trimmed to #{line_limit} symbols"
      else
        fh.info "Log line size is set not to be trimmed."
      end
      fh.info "VMDB settings END"

      fh.info "---"
      fh.info "DATABASE settings:"
      db_config = Config.new("database").config[Rails.env.to_sym]
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

        network = Initializer.get_network
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

      self.init_diagnostics
      # TODO:  Add pinging of gateways and Database
      #      pings =""
      #      gateways = `/sbin/route -n | awk '{ if ($4 ~ /G/) print $2; }'`.split("\n").collect {|g| pings << `ping -c 5 #{g}`}
      # TODO: Make this method executable as a scheduled queue item

      # execute or evaluate each diagnostic command
      @diags.each do  |diag|
        begin
          if diag[:evaluate?]
            res = eval(diag[:cmd])
          else
            res = `#{diag[:cmd]}`
          end
        rescue =>e
          $log.warn("Diagnostics: [#{diag[:msg]}] command [#{diag[:cmd]}] failed with error [#{e.to_s}]")
          next  # go to next diagnostic command if this one blew up
        end
        $log.info("Diagnostics: [#{diag[:msg]}]\n#{res}") unless res.blank?
      end

      vars = ""
      ENV.each { |k, v| vars << "#{k} = #{v}\n"}
      $log.info "Environment Variables: \n#{vars}" unless vars.blank?
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
        {:cmd => "File.open('/etc/hosts','r'){|f| f.read} if File.exists?('/etc/hosts')", :evaluate? => true, :msg => "Hosts file contents"},
        {:cmd => "File.open('/etc/fstab','r'){|f| f.read} if File.exists?('/etc/fstab')", :evaluate? => true, :msg => "Fstab file contents"},
        {:cmd => "echo start: date time is: #{Time.now.utc} >> #{gem_log}; gem list > #{gem_log}"},
        {:cmd => "echo start: date time is: #{Time.now.utc} >> #{ven_gem_log}; ls -1 vendor/gems > #{ven_gem_log}"},
        {:cmd => "echo start: date time is: #{Time.now.utc} >> #{rpm_log}; rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' |sort -k 1  > #{rpm_log} 2> /dev/null"},
        {:cmd => "echo start: date time is: #{Time.now.utc} >> #{dpkg_log}; dpkg -l > #{dpkg_log} 2> /dev/null"}
      ]
    end

    def self.get_comments(file)
      return "" unless File.exists?(file)

      fd = File.open(file, "r")
      comments = []
      while !fd.eof?
        line = fd.gets
        break unless line.starts_with?("#")
        comments.push(line)
      end
      fd.close
      comments
    end

    def self.apply_defaults(current, defaults)
      current = defaults.merge(current)
      current.each_key {|key|
        current[key] = defaults[key].merge(current[key])  if defaults.include?(key)
      }
    end

    def self.webservices(data, mode="activate")
      valid, errors = [true, []]
      if !["invoke", "disable"].include?(data.mode)
        valid = false; errors << [:mode, "webservices mode, \"#{data.mode}\", invalid. Should be one of: invoke of disable"]
      end
      unless data.timeout.is_a?(Fixnum)
        valid = false; errors << [:timeout, "timeout, \"#{data.timeout}\", invalid. Should be numeric"]
      end
      case mode
      when "activate"
        raise message unless valid
      when "validate"
        return [valid, errors]
      end

      case data.mode
      when "invoke"
        Config.hostwsdisabled false
      when "disable"
        Config.hostwsdisabled true
      else
        raise "mode, \"#{mode}\", is invalid, should be \"activate\" or \"validate\""
      end

      case data.contactwith
      when "ipaddress"
        Config.wscontactwith "ipaddress"
      when "hostname"
        Config.wscontactwith "hostname"
      else
        raise "contactwith, \"#{data.contactwith}\", is invalid, should be \"ipaddress\" or \"hostname\""
      end

      case data.nameresolution
      when true
        Config.wsnameresolution true
      when false
        Config.wsnameresolution false
      else
        raise "nameresolution, \"#{data.nameresolution}\", is invalid, should be \"true\" or \"false\""
      end

      Config.wstimeout data.timeout
    end

    AUTH_TYPES = %w(ldap ldaps httpd amazon database none)
    def self.authentication(data, mode="activate")
      valid, errors = [true, []]
      unless AUTH_TYPES.include?(data.mode)
        valid = false
        errors << [:mode, "authentication type, \"#{data.mode}\", invalid. Should be one of: #{AUTH_TYPES.join(", ")}"]
      end

      if data.mode == "ldap"
        if data.ldaphost.blank?
          valid = false; errors << [:ldaphost, "ldaphost can't be blank"]
        else
          # # XXXX Test connection to ldap host
          # # ldap=Net::LDAP.new( {:host => data.ldaphost, :port => 389} )
          # begin
          #   # ldap.bind
          #   sock = TCPSocket.new(data.ldaphost, 389)
          #   sock.close
          # rescue => err
          #   valid = false; errors << [:ldaphost, "unable to establish an ldap connection to host \"#{data.ldaphost}\", \"#{err}\""]
          # end
        end
      elsif data.mode == "amazon"
        if data.amazon_key.blank?
          valid = false; errors << [:amazon_key, "amazon key can't be blank"]
        end
        if data.amazon_secret.blank?
          valid = false; errors << [:amazon_secret, "amazon secret can't be blank"]
        end
      end

      case mode
      when "activate"
        raise message unless valid
      when "validate"
        return [valid, errors]
      else
        raise "mode, \"#{mode}\", is invalid, should be \"activate\" or \"validate\""
      end

      case data.mode
      when "ldap", "ldaps"
        User.ldaphost data.ldaphost
        User.basedn   data.basedn
      when "database"
        User.ldaphost "database"
      when "none"
        User.ldaphost ""
      end
    end

    def self.http_proxy_uri
      proxy = self.new("vmdb").config[:http_proxy] || {}
      return nil unless proxy[:host]
      proxy = proxy.dup

      user     = proxy.delete(:user)
      password = proxy.delete(:password)
      userinfo = "#{user}:#{password}".chomp(":") unless user.blank?

      proxy[:userinfo]   = userinfo
      proxy[:scheme]   ||= "http"
      proxy[:port]     &&= proxy[:port].to_i

      URI::Generic.build(proxy)
    end

    def self.queue_size(data)
      case data.to_s.downcase
      when "small"  then 2
      when "medium" then 4
      when "large"  then 6
      else
        return data.to_i if data.to_i > 0
        raise "Invalid value [#{data}] from queue_size"
      end
    end

    def self.log(data, mode = "activate")
      case mode
      when "activate"
        Vmdb::Logging.init
      when "validate"
        data = data.instance_variable_get(:@table) if data.kind_of?(OpenStruct)
        Vmdb::Logging.validate_config(data)
      else
        raise "mode, \"#{mode}\", is invalid, should be \"activate\" or \"validate\""
      end
    end

    def self.hostwsdisabled(value=nil)
      @@hostwsdisabled = value unless value==nil
      return @@hostwsdisabled
    end

    def self.wscontactwith(value=nil)
      @@wscontactwith = value unless value==nil
      return @@wscontactwith
    end

    def self.wsnameresolution(value=nil)
      @@wsnameresolution = value unless value==nil
      return @@wsnameresolution
    end

    def self.wstimeout(value=nil)
      @@wstimeout = value unless value==nil
      return @@wstimeout
    end

    def self.session(data, mode="activate")
      valid, errors = [true, []]
      unless data.timeout.is_a?(Fixnum)
        valid = false; errors << [:timeout, "timeout, \"#{data.timeout}\", invalid. Should be numeric"]
      end

      unless data.interval.is_a?(Fixnum)
        valid, key, message = [false, :interval, "interval, \"#{data.interval}\", invalid.  invalid. Should be numeric"]
      end

      if data.timeout == 0
        valid = false; errors << [:timeout, "timeout can't be zero"]
      end

      if data.interval == 0
        valid = false; errors << [:interval, "interval can't be zero"]
      end

      case mode
      when "activate"
        if valid
          Session.timeout data.timeout
          Session.interval data.interval
        else
          raise message
        end
      when "validate"
        [valid, errors]
      else
        raise "mode, \"#{mode}\", is invalid, should be \"activate\" or \"validate\""
      end
    end

    def self.server(data, mode="activate")
      valid, errors = [true, []]
      unless is_numeric?(data.listening_port) || data.listening_port.blank?
        valid = false; errors << [:listening_port, "listening_port, \"#{data.listening_port}\", invalid. Should be numeric"]
      end

      unless ["sql", "memory", "cache"].include?(data.session_store)
        valid = false; errors << [:session_store, "session_store, \"#{data.session_store}\", invalid. Should be one of \"sql\", \"memory\", \"cache\""]
      end

      unless ["any", "external"].include?(data.log_network_address)
        valid = false; errors << [:log_network_address, "log_network_address, \"#{data.log_network_address}\", invalid. Should be one of \"any\", \"external\""]
      end

      case mode
      when "activate"
        if valid
          Config.listening_port data.listening_port
          MiqServer.my_server.config_updated(data, mode) unless MiqServer.my_server.nil? rescue nil
        else
          raise message
        end
      when "validate"
        [valid, errors]
      else
        raise "mode, \"#{mode}\", is invalid, should be \"activate\" or \"validate\""
      end
    end

    def self.listening_port(value=nil)
      @@listening_port = value unless value==nil
      return @@listening_port
    end

    # SMTP Settings
    def self.smtp(data, mode="activate")
      valid, errors = [true, []]
      #host
      #domain
      #password

      #authentication
      if !["login", "plain", "none"].include?(data.authentication)
        valid = false; errors << [:mode, "authentication, \"#{data.mode}\", invalid. Should be one of: login, plain, or none"]
      end

      #user_name
      if data.user_name.blank? && data.authentication == "login"
        valid = false; errors << [:user_name, "cannot be blank for 'login' authentication"]
      end

      #port
      unless data.port.to_s =~ /^[0-9]*$/
        valid = false; errors << [:port, "\"#{data.port}\", invalid. Should be numeric"]
      end

      #from
      unless data.from =~ %r{^\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z$}i
        valid = false; errors << [:from, "\"#{data.from}\", invalid. Should be a valid email address"]
      end

      case mode
      when "activate"
        raise message unless valid
      when "validate"
        return [valid, errors]
      end
    end
    # end SMTP Settings

    def self.log_network_address
      log_network_address = self.new("vmdb").config[:server][:log_network_address]
      log_network_address ||= "any"
      log_network_address.downcase!
      case log_network_address.to_sym
      when :any
        return :any
      when :external
        return :external
      else
        raise "log_network_address, \"#{log_network_address}\", invalid. Should be one of \"any\", \"external\""
      end
    end

    def self.available_config_names
      return {
        "vmdb" => " EVM Server Main Configuration", # Name includes space so it is first in UI select box
        "event_handling" => "Event Handler Configuration",
        "broker_notify_properties" => "EVM Vim Broker Notification Properties",
        "capacity" => "EVM Capacity Management Configuration"
      }
    end

    def self.get_file(name)
      Vmdb::ConfigurationEncoder.dump(self.new(name.to_s).config)
    end

    def self.validate_file(name, contents)
      valid, new_cfg = self.load_and_validate_raw_contents(name, contents)
      return valid ? true : new_cfg
    end

    def self.save_file(name, contents)
      valid, new_cfg = self.load_and_validate_raw_contents(name, contents)
      return new_cfg unless valid
      new_cfg.save
      return true
    end

    def self.load_and_validate_raw_contents(name, contents)
      begin
        current = self.new(name.to_s)
        current.config = Vmdb::ConfigurationEncoder.load(contents)
        valid = current.validate
        return valid ? [true, current] : [false, current.errors]
      rescue => err
        return [false, [[:contents, "File contents are malformed, '#{err.message}'"]]]
      end
    end
  end
end
