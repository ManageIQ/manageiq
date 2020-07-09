require 'sys-uname'
require 'socket'

module MiqEnvironment
  # Return the fully qualified hostname for the local host.
  #
  def self.fully_qualified_domain_name
    Socket.gethostbyname(Socket.gethostname).first
  end

  # Return the local IP v4 address of the local host, ignoring private addresses.
  #
  def self.local_ip_address
    Socket.ip_address_list.detect { |addr| addr.ipv4? && !addr.ipv4_private? }&.ip_address
  end

  class Command
    EVM_KNOWN_COMMANDS = %w[apachectl memcached memcached-tool nohup service systemctl].freeze

    def self.supports_memcached?
      return @supports_memcached unless @supports_memcached.nil?
      @supports_memcached = is_linux? && is_appliance? && !is_container? && supports_command?('memcached') && supports_command?('memcached-tool') && supports_command?('service')
    end

    def self.supports_apache?
      return @supports_apache unless @supports_apache.nil?
      @supports_apache = is_appliance? && supports_command?('apachectl')
    end

    def self.supports_systemd?
      return @supports_systemd unless @supports_systemd.nil?
      @supports_systemd = is_appliance? && !is_container? && supports_command?('systemctl')
    end

    def self.supports_nohup_and_backgrounding?
      return @supports_nohup unless @supports_nohup.nil?
      @supports_nohup = is_appliance? && supports_command?('nohup')
    end

    def self.is_production_build?
      is_appliance? || is_podified? || is_container?
    end

    def self.is_container?
      return @is_container unless @is_container.nil?
      @is_container = ENV["CONTAINER"] == "true"
    end

    def self.is_podified?
      return @is_podified unless @is_podified.nil?
      @is_podified = is_container? && ContainerOrchestrator.available?
    end

    def self.is_appliance?
      return @is_appliance unless @is_appliance.nil?
      @is_appliance = ENV["APPLIANCE"] == "true"
    end

    # Return whether or not the current ManageIQ environment is a production
    # environment. Assumes production if Rails is not defined or if the Rails
    # environment is set to 'production'.
    #
    def self.is_production?
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
        MiqUtil.runcmd(which, :params => [[cmd]])
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
