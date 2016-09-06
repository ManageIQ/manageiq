require 'sys-uname'

module MiqEnvironment
  class Command
    EVM_KNOWN_COMMANDS = %w( memcached memcached-tool service apachectl nohup)

    def self.supports_memcached?
      return @supports_memcached unless @supports_memcached.nil?
      @supports_memcached = self.is_linux? && self.is_appliance? && self.supports_command?('memcached') && self.supports_command?('memcached-tool') && self.supports_command?('service')
    end

    def self.supports_apache?
      return @supports_apache unless @supports_apache.nil?
      @supports_apache = self.is_appliance? && self.supports_command?('apachectl')
    end

    def self.supports_nohup_and_backgrounding?
      return @supports_nohup unless @supports_nohup.nil?
      @supports_nohup = self.is_appliance? && self.supports_command?('nohup')
    end

    def self.is_appliance?
      return @is_appliance unless @is_appliance.nil?
      @is_appliance = self.is_linux? && File.exist?('/var/www/miq/vmdb')
    end

    def self.is_production?
      # Note: This method could be called outside of Rails, so check defined?(Rails)
      # Assume production if not defined or if set to 'production'
      defined?(Rails) ? Rails.env.production? : true
    end

    def self.is_linux?
      return @is_linux unless @is_linux.nil?
      @is_linux = (Sys::Platform::IMPL == :linux)
    end

    def self.rake_command
      "rake"
    end

    def self.runner_command
      "#{rails_command} runner"
    end

    def self.rails_command
      "rails"
    end

    def self.supports_command?(cmd)
      return false unless EVM_KNOWN_COMMANDS.include?(cmd)
      require "runcmd"

      begin
        # If 'which apachectl' returns non-zero, it wasn't found
        MiqUtil.runcmd("#{which} #{cmd}")
      rescue
        false
      else
        true
      end
    end

    def self.which
      case Sys::Platform::IMPL
      when :linux
        "which"
      else
        raise "Not yet supported platform: #{Sys::Platform::IMPL}"
      end
    end
  end
end
