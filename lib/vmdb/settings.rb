require 'config'
require_relative 'settings/database_source'
require_relative 'settings/hash_differ'

module Vmdb
  class Settings
    PASSWORD_FIELDS = %i(bind_pwd password amazon_secret).to_set.freeze

    def self.init
      reset_settings_constant(build_settings)
      reload!
    end

    def self.reload!
      ::Settings.reload!
      decrypt_passwords!(::Settings)
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
      changes = HashDiffer.changes(template_settings, hash).map { |h| h.values_at(:key, :value) }
      apply_settings_changes(miq_server, changes)
    end

    def self.for_miq_server(miq_server)
      decrypt_passwords!(build_settings(miq_server))
    end

    def self.template_settings
      raw_hash = YAML.load_file(Rails.root.join("config/vmdb.tmpl.yml"))
      decrypt_passwords!(raw_hash).deep_symbolize_keys!
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

    def self.build_settings(resource = nil)
      ::Config::Options.new.tap do |settings|
        settings.add_source!(Rails.root.join("config/vmdb.tmpl.yml").to_s)
        settings.add_source!(DatabaseSource.new(resource))
        settings.add_source!(Rails.root.join("config/settings.local.yml").to_s)
      end
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

    def self.apply_settings_changes(resource, changes)
      resource.transaction do
        index = resource.settings_changes.index_by(&:key)

        changes.each do |key, value|
          if value.present? && PASSWORD_FIELDS.include?(key.split("/").last.to_sym)
            value = MiqPassword.try_encrypt(value)
          end

          record = index.delete(key)
          if record
            record.update_attributes!(:value => value)
          else
            resource.settings_changes.create!(:key => key, :value => value)
          end
        end
        resource.settings_changes.destroy(index.values)
      end
    end
  end
end
