module VMDB
  class Config
    include Vmdb::Logging

    def self.for_resource(name, resource)
      new(name).tap do |config|
        config.config = Vmdb::Settings.for_resource(resource).to_hash
      end
    end

    @@sync_cfile = Sync.new
    @@cached_configs = {}

    require_relative 'configuration_encoder'

    def self.deep_clean_auth_for_log(log_auth)
      log_auth.each do |key, val|
        log_auth[key] = deep_clean_auth_for_log(val) if val.kind_of?(Hash)

        log_auth[key] = "********" if Vmdb::ConfigurationEncoder::PASSWORD_FIELDS.include?(key.to_s)

        log_auth[key].each do |p|
          p.keys.each { |key2| p[key2] = "********" if Vmdb::ConfigurationEncoder::PASSWORD_FIELDS.include?(key2.to_s) }
        end if [:user_proxies].include? key
      end
      log_auth
    end

    def self.clone_auth_for_log(auth)
      deep_clean_auth_for_log(auth.deep_clone)
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

      unless VMDB.model_loaded?(:Configuration)
        _log.debug "Using filesystem configurations since Configuration model is not loaded"
        return :filesystem
      end

      # Once the model is loaded, establish a connection or return an existing connection
      conn = ActiveRecord::Base.connection rescue nil
      unless conn && ActiveRecord::Base.connected?
        _log.debug "Using filesystem configurations since DB is not connected"
        return :filesystem
      end

      tables = conn.tables
      ['miq_servers', 'configurations'].each do |t|
        unless tables.include?(t)
          _log.warn("Using filesystem configurations since [#{t}] table does not exist!")
          return :filesystem
        end
      end

      if MiqServer.my_server.nil?
        _log.warn("Using filesystem configurations until MiqServer is known.  This may be resolved by next server startup. ")
        return :filesystem
      end

      # Now that the DB is to be used, invalidate the cached configs from the filesystem
      invalidate_all
      @use_db_for_config = true
      _log.debug("Using database configurations")
      :database
    end

    attr_reader   :name, :configuration_source
    attr_accessor :config
    attr_accessor :errors

    def initialize(name, autoload = true)
      @name = name
      @config = @errors = nil
      return unless autoload

      _root = File.join(File.expand_path(Rails.root))

      @cfile = File.join(_root, "config/#{name}.yml")
      @ctmpl = File.join(_root, "config/#{name}.tmpl.yml")
      @cfile_db = @cfile + ".db"
      @config_mtime = @template_mtime = nil

      @configuration_source = self.class.configuration_source(@name)
      if self.cached_config_valid?
        @config = @@cached_configs[name][:data].deep_clone
      else
        _log.debug "#{@@cached_configs.key?(name) && !@@cached_configs[name][:mtime].nil? ? "Rel" : "L"}oading configuration file for \"#{name}\""

        @@sync_cfile.synchronize(:EX) do
          if configuration_source == :filesystem && 'database' == name && !File.exist?(@cfile) && File.exist?(@ctmpl)
            puts("MIQ(Config.initialize) Creating #{@cfile} from #{@ctmpl}")
            FileUtils.copy(@ctmpl, @cfile)
          end
        end
        defaults = retrieve_config(:tmpl)
        current =  retrieve_config(:yml)
        raise "MIQ(Config.initialize) unable to locate configuration file or template file for \"#{name}\"" if current.nil? && defaults.nil?

        # if the database is the source of the configuration, create or update db record and rename the config file if an override was used
        _log.debug("Source of configuration: #{configuration_source}")
        if configuration_source == :database
          server = MiqServer.my_server
          raise "MiqServer.my_server cannot be nil" if server.nil?
          @db_record = server.configurations.where(:typ => @name).first

          conf = current

          if @db_record.nil? && conf.nil?
            conf = defaults
            _log.info("[#{@name}] - Using template to populate DB since settings were not found")
          end

          @db_record = Configuration.create_or_update(server, conf, name) unless conf.blank?

          @@sync_cfile.synchronize(:EX) do
            # rename the config file if we already created the db_record and the file exists
            if File.exist?(@cfile) && !@db_record.nil?
              File.rename(@cfile, @cfile_db)
              _log.info("[#{@name}] Config in DB will now be used.  Renamed file to [#{@cfile_db}]")
            end
          end
          # use the record from the db
          current = @db_record.settings if @db_record
        end
        current = Config.apply_defaults(current, defaults) unless current.nil? || defaults.nil?
        current = defaults if current.nil?

        @config = current
        update_cache_metadata
      end

      @config_mtime   = @@cached_configs[@name][:mtime]
      @template_mtime = @@cached_configs[@name][:mtime_tmpl]

      @config
    end

    def self.load_config_file(fname)
      data = IO.read(fname) if File.exist?(fname)
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
      # log_header = "[#{@name}]"
      server = MiqServer.my_server
      return Time.at(0) if server.nil?

      conf = server.configurations.select("updated_on").where(:typ => @name).first
      return Time.at(0) if conf.nil?

      mtime = conf.updated_on
      # _log.debug("#{log_header} Config mtime retrieved from db [#{mtime}]") unless $log.nil? || mtime.nil?
      normalize_time(mtime) if mtime
    end

    def config_mtime_from_file(typ)
      # log_header = "[#{@name}] type: [#{typ}]"
      fname = typ == :yml ? @cfile : @ctmpl
      mtime = File.mtime(fname) if File.exist?(fname)
      # _log.debug("#{log_header} Config mtime retrieved from file [#{mtime}]") unless $log.nil? || mtime.nil?
      normalize_time(mtime)
    end

    def template_configuration
      self.class.load_config_file(@ctmpl)
    end

    def merge_from_template(*args)
      template_configuration.fetch_path(*args).tap do |value|
        args << value
        config.store_path(*args)
        save
      end
    end

    def fetch_with_fallback(*args)
      value = config.fetch_path(*args)
      value.nil? ? merge_from_template(*args) : value
    end
    alias_method :merge_from_template_if_missing, :fetch_with_fallback

    def get(section, key = nil)
      # get(section, key) -> value
      # get(section) -> hash of section values
      return nil unless config.keys.include?(section)

      if key.nil?
        config[section]
      else
        config[section][key]
      end
    end

    def set(section, key = nil, value = nil)
      # set(section, key, value)
      # set(section, hash)
      # set(hash)
      if key.nil?
        # set(hash) -> section holds a hash of the entire configuration
        self.config = section
      else
        if value.nil?
          # set(section, hash) -> key holds the hash for specified section
          config[section] = key
        else
          # set(section, key, value)
          config[section][key] = value
        end
      end
    end

    # Get the worker settings converted to bytes, seconds, etc.
    def get_worker_setting(klass, setting = nil)
      _get_worker_setting(klass, setting, false)
    end

    # Get the worker settings as they are in the yaml: 1.seconds, 1, etc.
    def get_raw_worker_setting(klass, setting = nil)
      _get_worker_setting(klass, setting, true)
    end

    def _get_worker_setting(klass, setting = nil, raw = false)
      # get a specific setting.... if provided
      klass = Object.const_get(klass) unless klass.class == Class
      full_settings = klass.worker_settings(:config => config, :raw => raw)
      return full_settings if setting.nil?

      return full_settings.fetch_path(*setting) if setting.kind_of?(Array)
      full_settings.fetch_path(setting)
    end

    def set_worker_setting!(klass, setting, value)
      klass = Object.const_get(klass) unless klass.class == Class

      # find the key for the class and set the value
      keys = klass.config_settings_path + setting.to_miq_a
      config.store_path(keys, value)
    end

    def save
      raise "configuration invalid, see errors for details" unless validate

      begin
        Vmdb::ConfigurationEncoder.validate!(@config)
      rescue SyntaxError
        raise "Syntax error while parsing new configuration!"
      end

      svr = MiqServer.my_server(true)
      case configuration_source
      when :database
        @db_record = Configuration.create_or_update(svr, @config, @name)
        save_file(@cfile_db) unless Rails.env.test?
        _log.info("Saved Config [#{@name}] from database in file: [#{@cfile_db}]")
      when :filesystem
        save_file(@cfile_db) unless Rails.env.test?
        _log.info("Saved Config [#{@name}] in file: [#{@cfile_db}]")
      end
      update_cache_metadata

      activate
    end

    def save_file(filename)
      @@sync_cfile.synchronize(:EX) do
        comments = Config.get_comments(filename) # Save comments from cfg file before deleting.
        comments = Config.get_comments(@ctmpl) if comments == "" # Try the template file if none in the cfg file.
        File.delete(filename) if File.exist?(filename)
        # File.open(@cfile, "w") {|f| YAML.dump(Config.stringify(@config), f)}
        fd = File.open(filename, "w")
        fd.write(comments.join) if comments.kind_of?(Array)
        Vmdb::ConfigurationEncoder.dump(@config, fd)
        fd.close
      end
    end

    def stale?
      return true unless cached_config_valid?
      return true if (@@cached_configs.fetch_path(@name, :mtime) != @config_mtime)
      return true if (@@cached_configs.fetch_path(@name, :mtime_tmpl) != @template_mtime)
      false
    end

    def cached_config_valid?
      return false unless @@cached_configs.key?(@name)

      config_mtime = config_mtime_from_file(:yml)
      db_config_mtime = config_mtime_from_db if configuration_source == :database

      # if the database is the configuration_source, check if the DB record needs to be created or if the config mtime is newer than the DB mtime
      if configuration_source == :database
        if db_config_mtime.nil?
          _log.debug("Cache Miss because DB mtime does not exist and the DB is the configuration source #{@name}")
          return false
        elsif !config_mtime.nil? && config_mtime > db_config_mtime
          _log.debug("Cache Miss because config mtime [#{config_mtime}] is newer than DB mtime [#{db_config_mtime}] for #{@name}")
          return false
        end
      end

      config_mtime = db_config_mtime unless db_config_mtime.nil?

      template_mtime = config_mtime_from_file(:tmpl)
      msg = "@name: [#{@name}], mtime/cached: [#{config_mtime}/#{@@cached_configs[@name][:mtime]}], mtime_tmpl/cached: [#{template_mtime}/#{@@cached_configs[@name][:mtime_tmpl]}]"
      if (@@cached_configs[@name][:mtime] == config_mtime) && (@@cached_configs[@name][:mtime_tmpl] == template_mtime)
        return true
      else
        _log.debug("Cache Miss: #{msg}")
        return false
      end
      false
    end

    def update_cache_metadata
      @@cached_configs[@name] = {} if @@cached_configs[@name].blank?
      @@cached_configs[@name][:data] = @config.deep_clone
      @@cached_configs[@name][:mtime] = configuration_source == :database ? config_mtime_from_db : config_mtime_from_file(:yml)
      @@cached_configs[@name][:mtime_tmpl] =  config_mtime_from_file(:tmpl)

      @config_mtime   = @@cached_configs[@name][:mtime]
      @template_mtime = @@cached_configs[@name][:mtime_tmpl]
    end

    def validate
      valid, @errors = Validator.new(self).validate
      valid
    end

    def activate
      Activator.new(self).activate
    end

    def self.refresh_configs
      # Refresh all cached configs
      @@cached_configs.each_key do |k|
        Config.new(k.to_s)
        _log.debug("[#{k.inspect}] config refreshed")
      end
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

    private

    def self.get_comments(file)
      return "" unless File.exist?(file)

      fd = File.open(file, "r")
      comments = []
      until fd.eof?
        line = fd.gets
        break unless line.starts_with?("#")
        comments.push(line)
      end
      fd.close
      comments
    end

    def self.apply_defaults(current, defaults)
      current = defaults.merge(current)
      current.each_key do|key|
        current[key] = defaults[key].merge(current[key])  if defaults.include?(key)
      end
    end

    # NOTE: Used by Configuration -> Advanced
    def self.get_file(name)
      Vmdb::ConfigurationEncoder.dump(new(name.to_s).config)
    end

    # NOTE: Used by Configuration -> Advanced
    def self.save_file(name, contents)
      config = new(name.to_s)

      begin
        config.config = Vmdb::ConfigurationEncoder.load(contents)
        config.validate
      rescue StandardError, SyntaxError => err
        config.errors = [[:contents, "File contents are malformed, '#{err.message}'"]]
      end

      return config.errors unless config.errors.blank?
      config.save
      true
    end
  end
end
