ENV['BUNDLE_GEMFILE'] ||= File.expand_path("Gemfile", File.join(File.dirname(__FILE__)))

require 'rubygems'

begin
  require 'bundler_ext'
rescue LoadError
end

module CFME
  class BundlerSetup
    REQUIRED_BUNDLER_EXT_VARIABLES = %w(BEXT_NOSTRICT BEXT_PKG_PREFIX BEXT_ACTIVATE_VERSIONS)

    def self.use_bundler_ext?
      !!defined?(BundlerExt) && bundler_ext_configured?
    end

    def self.bundler_ext_configured?
      missing_variables = REQUIRED_BUNDLER_EXT_VARIABLES.reject { |var| ENV.key?(var) }

      if missing_variables.empty?
        true
      else
        warn "bundler_ext was found but missing the required env variable(s): #{missing_variables.join(" ")}"
        false
      end
    end

    def self.system_setup(gemfile, *args)
      if use_bundler_ext?
        puts "Using bundler_ext"
        BundlerExt.system_setup(gemfile, *args)
      else
        require 'bundler/setup'
      end
    end

    def self.system_require(gemfile, *args)
      if use_bundler_ext?
        puts "Using bundler_ext"
        BundlerExt.system_require(gemfile, *args)
      else
        Bundler.require(*args)
      end
    end
  end
end

CFME::BundlerSetup.system_setup(ENV['BUNDLE_GEMFILE'], :default)
