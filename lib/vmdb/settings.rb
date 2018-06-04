require 'config'
require_dependency 'patches/config_patch'
require_dependency 'vmdb/settings/database_source'
require_dependency 'vmdb/settings/hash_differ'
require_dependency 'vmdb/settings_walker'

module Vmdb
  class Settings
    extend Vmdb::SettingsWalker::ClassMethods
    include Vmdb::Logging

    class ConfigurationInvalid < StandardError
      attr_accessor :errors

      def initialize(errors)
        @errors = errors
        message = errors.map { |k, v| "#{k}: #{v}" }.join("; ")
        super(message)
      end
    end

    PASSWORD_FIELDS = Vmdb::SettingsWalker::PASSWORD_FIELDS
    DUMP_LOG_FILE   = Rails.root.join("log/last_settings.txt").freeze

    # RESET_COMMAND remove record for selected key and specific resource
    # RESET_ALL_COMMAND remove all records for selected key and all resources
    MAGIC_VALUES = [DELETE_COMMAND      = "<<reset>>".freeze,
                    DELETE_ALL_COMMAND  = "<<reset_all>>".freeze].freeze

    cattr_accessor :last_loaded

    def self.init
      ::Config.overwrite_arrays = true
      reset_settings_constant(for_resource(:my_server))
      on_reload
    end

    def self.on_reload
      self.last_loaded = Time.now.utc
      dump_to_log_directory(::Settings)
    end

    def self.reload!
      ::Settings.reload!
      activate
    end

    def self.walk(settings = ::Settings, path = [], &block)
      super(settings, path, &block)
    end

    def self.activate
      VMDB::Config::Activator.new(::Settings).activate
    end

    def self.validator(settings = ::Settings)
      VMDB::Config::Validator.new(settings)
    end
    private_class_method :validator

    def self.validate(settings = ::Settings)
      validator(settings).validate
    end

    def self.valid?
      validator.valid?
    end

    def self.save!(resource, hash)
      new_settings = build_without_local(resource).load!.merge!(hash).to_hash
      settings_to_validate = remove_magic_values(new_settings.deep_clone)

      valid, errors = validate(settings_to_validate)
      raise ConfigurationInvalid.new(errors) unless valid # rubocop:disable Style/RaiseArgs

      hash_for_parent = parent_settings_without_local(resource).load!.to_hash
      diff = HashDiffer.diff(hash_for_parent, new_settings)
      encrypt_passwords!(diff)
      deltas = HashDiffer.diff_to_deltas(diff)
      apply_settings_changes(resource, deltas)
    end

    def self.save_yaml!(resource, contents)
      require 'yaml'
      hash =
        begin
          decrypt_passwords!(YAML.load(contents))
        rescue => err
          raise ConfigurationInvalid.new(:contents => "File contents are malformed: #{err.message.inspect}")
        end

      save!(resource, hash)
    end

    def self.destroy!(resource, keys)
      return if keys.blank?
      settings_path = File.join("/", keys.collect(&:to_s))
      resource.settings_changes.where("key LIKE ?", "#{settings_path}%").destroy_all
    end

    def self.for_resource(resource)
      build(resource).load!
    end

    def self.for_resource_yaml(resource)
      require 'yaml'
      encrypt_passwords!(for_resource(resource).to_hash).to_yaml
    end

    def self.template_settings
      build_template.load!
    end

    def self.dump_to_log_directory(settings)
      DUMP_LOG_FILE.write(mask_passwords!(settings.to_hash).to_yaml)
    end

    def self.build_template
      ::Config::Options.new.tap do |settings|
        template_sources.each { |s| settings.add_source!(s) }
      end
    end
    private_class_method :build_template

    def self.build(resource)
      build_without_local(resource).tap do |settings|
        local_sources.each { |s| settings.add_source!(s) } if resource_is_local?(resource)
      end
    end
    private_class_method :build

    def self.resource_is_local?(resource)
      resource == :my_server || resource.try(:is_local?)
    end
    private_class_method :resource_is_local?

    def self.parent_settings_without_local(resource)
      build_template.tap do |settings|
        DatabaseSource.parent_sources_for(resource).each do |db_source|
          settings.add_source!(db_source)
        end
      end
    end
    private_class_method :parent_settings_without_local

    def self.build_without_local(resource)
      build_template.tap do |settings|
        DatabaseSource.sources_for(resource).each do |db_source|
          settings.add_source!(db_source)
        end
      end
    end
    private_class_method :build_without_local

    def self.template_roots
      Vmdb::Plugins.instance.vmdb_plugins.collect { |p| p.root.join('config') } << Rails.root.join('config')
    end
    private_class_method :template_roots

    def self.template_sources
      template_roots.flat_map do |root|
        [
          root.join("settings.yml").to_s,
          root.join("settings/#{Rails.env}.yml").to_s,
          root.join("environments/#{Rails.env}.yml").to_s
        ]
      end
    end
    private_class_method :template_sources

    def self.local_sources
      template_roots.flat_map do |root|
        [
          root.join("settings.local.yml").to_s,
          root.join("settings/#{Rails.env}.local.yml").to_s,
          root.join("environments/#{Rails.env}.local.yml").to_s
        ]
      end
    end
    private_class_method :local_sources

    # This is a near copy of Config.load_and_set_settings, but we can't use that
    # method as it also calls Config.load_files, which enforces specific file
    # sources and doesn't allow you insert new sources into the middle of the
    # stack.
    def self.reset_settings_constant(settings)
      Kernel.send(:remove_const, ::Config.const_name) if Kernel.const_defined?(::Config.const_name)
      Kernel.const_set(::Config.const_name, settings)
    end
    private_class_method :reset_settings_constant

    def self.apply_settings_changes(resource, deltas)
      resource.transaction do
        index = resource.settings_changes.index_by(&:key)

        deltas.each do |delta|
          record = index.delete(delta[:key])
          next if process_magic_value(resource, delta)
          if record
            record.update_attributes!(delta)
          else
            resource.settings_changes.create!(delta)
          end
        end
        resource.settings_changes.destroy(index.values)
      end
    end
    private_class_method :apply_settings_changes

    def self.process_magic_value(resource, delta)
      return false unless MAGIC_VALUES.include?(delta[:value])
      case delta[:value]
      when DELETE_COMMAND
        _log.info("removing custom settings #{delta[:key]} on #{resource.class} id:#{resource.id}")
        resource.settings_changes.where("key LIKE ?", "#{delta[:key]}%").destroy_all
      when DELETE_ALL_COMMAND
        _log.info("resetting #{delta[:key]} to default for all resorces")
        SettingsChange.where("key LIKE ?", "#{delta[:key]}%").destroy_all
      end
      true
    end
    private_class_method :process_magic_value

    def self.walk_hash(hash, &block)
      hash.each do |key, value|
        yield key, value, hash
        walk_hash(value, &block) if value&.class == Hash
      end
    end
    private_class_method :walk_hash

    def self.remove_magic_values(hash)
      walk_hash(hash) { |key, value, owner| owner.delete(key) if MAGIC_VALUES.include?(value) }
      hash
    end
    private_class_method :remove_magic_values
  end
end
