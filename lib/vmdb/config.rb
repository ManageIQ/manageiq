module VMDB
  class Config
    include Vmdb::Logging

    def self.for_resource(name, resource)
      new(name).tap do |config|
        config.config = filter_settings_by_name(Vmdb::Settings.for_resource(resource), name)
      end
    end

    attr_accessor :errors, :name

    def initialize(name)
      _log.debug("VMDB::Config.new is deprecated.  Prefer using Settings directly.")
      @name = name
      @errors = nil
    end

    def config
      _log.debug("VMDB::Config#config is deprecated.  Prefer using Settings directly.")
      @config ||= self.class.filter_settings_by_name(::Settings.to_hash, name).to_hash
    end

    def config=(settings)
      @config = self.class.filter_settings_by_name(settings.to_hash, name).to_hash
    end

    def validate
      valid, @errors = Validator.new(self).validate
      valid
    end

    def activate
      Activator.new(self).activate
    end

    # Get the worker settings as they are in the yaml: 1.seconds, 1, etc.
    # NOTE: Used by Configuration
    def get_raw_worker_setting(klass, setting = nil)
      raise "only available for vmdb" if name != "vmdb"
      klass = klass.to_s.constantize unless klass.kind_of?(Class)
      full_settings = klass.worker_settings(:config => config, :raw => true)
      setting ? full_settings.fetch_path(setting) : full_settings
    end

    def set_worker_setting!(klass, setting, value)
      raise "only available for vmdb" if name != "vmdb"
      klass = klass.to_s.constantize unless klass.kind_of?(Class)

      # find the key for the class and set the value
      keys = klass.config_settings_path + Array.wrap(setting)
      config.store_path(keys, value)
    end

    def save(resource = MiqServer.my_server)
      resource.set_config(config)
    end

    # NOTE: Used by Configuration -> Advanced
    def self.get_file
      Vmdb::Settings.encrypt_passwords!(::Settings.to_hash).to_yaml
    end

    # NOTE: Used by Configuration -> Advanced
    def self.save_file(contents, resource = MiqServer.my_server)
      config = new("vmdb")

      begin
        config.config = Vmdb::Settings.decrypt_passwords!(YAML.load(contents))
        config.validate
      rescue StandardError, Psych::SyntaxError => err
        config.errors = [[:contents, "File contents are malformed, '#{err.message}'"]]
      end

      return config.errors unless config.errors.blank?
      config.save(resource)
      true
    end

    # protected
    def self.filter_settings_by_name(settings, name)
      name == "vmdb" ? settings : settings[name.to_sym]
    end
  end
end
