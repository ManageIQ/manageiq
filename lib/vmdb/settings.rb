require 'config'
require_relative 'settings/database_source'

module Vmdb
  class Settings
    def self.init
      reset_settings_constant
      ::Settings.add_source!(Rails.root.join("config/vmdb.tmpl.yml").to_s)
      ::Settings.add_source!(DatabaseSource.new)
      ::Settings.add_source!(Rails.root.join("config/settings.local.yml").to_s)
      ::Settings.load!
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
  end
end
