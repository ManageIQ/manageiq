require 'config'
require_dependency 'patches/config_patch'
require_dependency 'vmdb/settings/database_source'
require_dependency 'vmdb/settings/hash_differ'

module Vmdb
  class Settings
    PASSWORD_FIELDS = %i(bind_pwd password amazon_secret).to_set.freeze

    def self.init
      reset_settings_constant(for_resource(my_server))
    end

    def self.walk(settings = ::Settings, path = [], &block)
      settings.each do |key, value|
        new_path = path.dup << key

        yield key, value, new_path, settings

        case value
        when settings.class
          walk(value, new_path, &block)
        when Array
          value.each_with_index do |v, i|
            walk(v, new_path.dup << i, &block) if v.kind_of?(settings.class)
          end
        end
      end
      settings
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

    def self.save!(miq_server, hash)
      raise "configuration invalid" unless VMDB::Config::Validator.new(hash).valid?
      diff = HashDiffer.diff(template_settings.to_hash, hash)
      encrypt_passwords!(diff)
      deltas = HashDiffer.diff_to_deltas(diff)
      apply_settings_changes(miq_server, deltas)
    end

    def self.for_resource(resource)
      build(resource).load!
    end

    def self.template_settings
      build_template.load!
    end

    def self.mask_passwords!(settings)
      walk_passwords(settings) { |k, v, h| h[k] = "********" }
    end

    def self.decrypt_passwords!(settings)
      walk_passwords(settings) { |k, v, h| h[k] = MiqPassword.try_decrypt(v) }
    end

    def self.encrypt_passwords!(settings)
      walk_passwords(settings) { |k, v, h| h[k] = MiqPassword.try_encrypt(v) }
    end

    private

    def self.build_template
      ::Config::Options.new.tap do |settings|
        template_sources.each { |s| settings.add_source!(s) }
      end
    end

    def self.build(resource)
      build_template.tap do |settings|
        settings.add_source!(DatabaseSource.new(resource))
        local_sources.each { |s| settings.add_source!(s) }
      end
    end

    def self.template_sources
      [
        Rails.root.join("config/settings.yml").to_s,
        Rails.root.join("config/settings/#{Rails.env}.yml").to_s,
        Rails.root.join("config/environments/#{Rails.env}.yml").to_s
      ]
    end

    def self.local_sources
      [
        Rails.root.join("config/settings.local.yml").to_s,
        Rails.root.join("config/settings/#{Rails.env}.local.yml").to_s,
        Rails.root.join("config/environments/#{Rails.env}.local.yml").to_s
      ]
    end

    # This is a near copy of Config.load_and_set_settings, but we can't use that
    # method as it also calls Config.load_files, which enforces specific file
    # sources and doesn't allow you insert new sources into the middle of the
    # stack.
    def self.reset_settings_constant(settings)
      Kernel.send(:remove_const, ::Config.const_name) if Kernel.const_defined?(::Config.const_name)
      Kernel.const_set(::Config.const_name, settings)
    end

    def self.walk_passwords(settings)
      walk(settings) do |key, value, _path, owning|
        yield(key, value, owning) if value.present? && PASSWORD_FIELDS.include?(key.to_sym)
      end
    end

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

    # Since `#load` occurs very early in the boot process, we must ensure that
    # we do not fail in cases where the database is not yet created, not yet
    # available, or has not yet been seeded.
    def self.my_server
      resource_queryable? ? MiqServer.my_server(true) : nil
    end

    def self.resource_queryable?
      database_connectivity? && SettingsChange.table_exists?
    end

    def self.database_connectivity?
      conn = ActiveRecord::Base.connection rescue nil
      conn && ActiveRecord::Base.connected?
    end

  end
end
