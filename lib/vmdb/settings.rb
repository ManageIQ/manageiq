require 'config'
require_relative 'settings/database_source'
require_relative 'settings/hash_differ'

module Vmdb
  class Settings
    def self.init
      reset_settings_constant(build_settings)
      reload!
    end

    def self.reload!
      ::Settings.reload!
      ::Settings.merge!(decrypted_password_fields(::Settings))
    end

    def self.walk(settings = ::Settings, path = [], &block)
      settings.each do |key, value|
        new_path = path.dup << key
        yield key, value, new_path, settings
        walk(value, new_path, &block) if value.instance_of?(settings.class)
      end
      settings
    end

    def self.save!(miq_server, hash)
      raise "configuration invalid" unless VMDB::Config::Validator.new(hash).valid?
      changes = HashDiffer.changes(template_settings, hash).map { |h| h.values_at(:key, :value) }
      apply_settings_changes(miq_server, changes)
    end

    def self.for_miq_server(miq_server)
      decrypt_passwords_fields!(build_settings(miq_server))
    end

    def self.template_settings
      raw_hash = YAML.load_file(Rails.root.join("config/vmdb.tmpl.yml"))
      decrypt_passwords_fields!(raw_hash).deep_symbolize_keys!
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

    PASSWORD_FIELDS = %i(bind_pwd password amazon_secret).to_set.freeze

    def self.decrypted_password_fields(settings)
      hash = {}
      walk(settings) do |key, value, path, _owning|
        hash.store_path(path, MiqPassword.try_decrypt(value)) if PASSWORD_FIELDS.include?(key) && value.present?
      end
      hash
    end

    def self.decrypt_passwords_fields!(settings)
      settings.merge!(decrypted_password_fields(settings))
    end

    def self.encrypt_password_field(key, value)
      PASSWORD_FIELDS.include?(key.to_sym) && value.present? ? MiqPassword.try_encrypt(value) : value
    end

    def self.apply_settings_changes(resource, changes)
      resource.transaction do
        index = resource.settings_changes.index_by(&:key)

        changes.each do |key, value|
          value = encrypt_password_field(key.split("/").last.to_sym, value)

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
