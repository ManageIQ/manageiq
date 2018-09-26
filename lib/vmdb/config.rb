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
      @name = name
      @errors = nil
    end
    Vmdb::Deprecation.deprecate_methods(self, :initialize => "Prefer using Settings directly")

    def config
      @config ||= self.class.filter_settings_by_name(::Settings.to_hash, name).to_hash
    end
    Vmdb::Deprecation.deprecate_methods(self, :config => "Prefer using Settings directly")

    def config=(settings)
      @config = self.class.filter_settings_by_name(settings.to_hash, name).to_hash
    end

    def validate
      valid, @errors = Vmdb::Settings::Validator.new(self).validate
      valid
    end

    def activate
      Vmdb::Settings::Activator.new(self).activate
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
    def self.get_file(resource = MiqServer.my_server)
      resource.settings_for_resource_yaml
    end

    # NOTE: Used by Configuration -> Advanced
    def self.save_file(contents, resource = MiqServer.my_server)
      resource.add_settings_for_resource_yaml(contents)
    rescue Vmdb::Settings::ConfigurationInvalid => err
      err.errors
    else
      true
    end

    # protected
    def self.filter_settings_by_name(settings, name)
      name == "vmdb" ? settings : settings[name.to_sym]
    end
  end
end
