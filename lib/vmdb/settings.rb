require 'config'
require_relative 'settings/database_source'

module Vmdb
  class Settings
    def self.init
      reset_settings_constant
      ::Settings.add_source!(Rails.root.join("config/vmdb.tmpl.yml").to_s)
      ::Settings.add_source!(DatabaseSource.new)
      ::Settings.add_source!(Rails.root.join("config/settings.local.yml").to_s)
      reload!
    end

    def self.reload!
      ::Settings.reload!
      ::Settings.merge!(decrypted_password_fields)
    end

    def self.walk(settings = ::Settings, path = [], &block)
      settings.each do |key, value|
        new_path = path.dup << key
        yield key, value, new_path, settings
        walk(value, new_path, &block) if value.instance_of?(settings.class)
      end
      settings
    end

    private

    # This is a near copy of Config.load_and_set_settings, but we can't use that
    # method as it also calls Config.load_files, which enforces specific file
    # sources and doesn't allow you insert new sources into the middle of the
    # stack.
    def self.reset_settings_constant
      Kernel.send(:remove_const, ::Config.const_name) if Kernel.const_defined?(::Config.const_name)
      Kernel.const_set(::Config.const_name, ::Config::Options.new)
    end

    PASSWORD_FIELDS = %i(bind_pwd password amazon_secret).to_set.freeze

    def self.decrypted_password_fields
      hash = {}
      walk do |key, value, path, _settings|
        hash.store_path(path, MiqPassword.try_decrypt(value)) if PASSWORD_FIELDS.include?(key) && value.present?
      end
      hash
    end
  end
end
