require 'sys-uname'
require 'socket'

module MiqEnvironment
  def self.arch
    Sys::Platform::ARCH
  end

  # Return the fully qualified hostname for the local host.
  #
  def self.fully_qualified_domain_name
    hostname    = Socket.gethostname
    addrinfo    = Addrinfo.getaddrinfo(hostname, nil, nil, :STREAM).first
    fqdn, _port = addrinfo.getnameinfo
    fqdn
  end

  # Return the local IP v4 address of the local host
  #
  def self.local_ip_address
    ipv4_addrs = Socket.ip_address_list.select(&:ipv4?).sort_by(&:ip_address)

    # Prioritize "public" aka non-loopback non-private addresses first, then
    # prefer private addresses, then take whatever we can get
    local_addr   = ipv4_addrs.detect { |ip| !ip.ipv4_loopback? && !ip.ipv4_private? }
    local_addr ||= ipv4_addrs.detect { |ip| !ip.ipv4_loopback? }
    local_addr ||= ipv4_addrs.first

    local_addr&.ip_address
  end

  def self.manageiq_uid
    @manageiq_uid ||= begin
      Process::UID.from_name("manageiq") if Command.is_appliance?
    rescue ArgumentError
      nil
    end
  end

  def self.manageiq_gid
    @manageiq_gid ||= begin
      Process::GID.from_name("manageiq") if Command.is_appliance?
    rescue ArgumentError
      nil
    end
  end

  class Command
    EVM_KNOWN_COMMANDS = %w[apachectl docker nohup podman service systemctl].freeze

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

      @is_podified = is_container? &&
                     File.exist?("/run/secrets/kubernetes.io/serviceaccount/token") &&
                     File.exist?("/run/secrets/kubernetes.io/serviceaccount/ca.crt")
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

      require "awesome_spawn"

      begin
        # If 'which apachectl' returns non-zero, it wasn't found
        AwesomeSpawn.run!(which, :params => [cmd])
      rescue AwesomeSpawn::CommandResultError
        false
      else
        true
      end
    end

    def self.which
      case Sys::Platform::IMPL
      when :linux, :macosx
        "which"
      else
        raise "Not yet supported platform: #{Sys::Platform::IMPL}"
      end
    end
  end
end
