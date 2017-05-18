require 'config'
require_dependency 'patches/config_patch'
require_dependency 'vmdb/settings/database_source'
require_dependency 'vmdb/settings/hash_differ'
require_dependency 'vmdb/settings/walker'

module Vmdb
  class Settings
    PASSWORD_FIELDS = Vmdb::Settings::Walker::PASSWORD_FIELDS
    DUMP_LOG_FILE   = Rails.root.join("log/last_settings.txt").freeze

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
      Walker.walk(settings, path, &block)
    end

    def self.activate
      VMDB::Config::Activator.new(::Settings).activate
    end

    def self.validate
      VMDB::Config::Validator.new(::Settings).validate
    end

    def self.valid?
      validate.first
    end

    def self.save!(resource, hash)
      new_settings = build_without_local(resource).load!.merge!(hash).to_hash
      raise "configuration invalid" unless VMDB::Config::Validator.new(new_settings).valid?
      hash_for_parent = parent_settings_without_local(resource).load!.to_hash
      diff = HashDiffer.diff(hash_for_parent, new_settings)
      encrypt_passwords!(diff)
      deltas = HashDiffer.diff_to_deltas(diff)
      apply_settings_changes(resource, deltas)
    end

    def self.for_resource(resource)
      build(resource).load!
    end

    def self.template_settings
      build_template.load!
    end

    def self.mask_passwords!(settings)
      Walker.mask_passwords!(settings)
    end

    def self.decrypt_passwords!(settings)
      Walker.decrypt_passwords!(settings)
    end

    def self.encrypt_passwords!(settings)
      Walker.encrypt_passwords!(settings)
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
      Vmdb::Plugins.instance.vmdb_plugins.each_with_object([Rails.root.join('config')]) do |plugin, roots|
        roots << plugin.root.join('config')
      end
    end
    private_class_method :template_roots

    def self.template_sources
      template_roots.each_with_object([]) do |root, sources|
        sources.push(
          root.join("settings.yml").to_s,
          root.join("settings/#{Rails.env}.yml").to_s,
          root.join("environments/#{Rails.env}.yml").to_s
        )
      end
    end
    private_class_method :template_sources

    def self.local_sources
      template_roots.each_with_object([]) do |root, sources|
        sources.push(
          root.join("settings.local.yml").to_s,
          root.join("settings/#{Rails.env}.local.yml").to_s,
          root.join("environments/#{Rails.env}.local.yml").to_s
        )
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
  end
end
