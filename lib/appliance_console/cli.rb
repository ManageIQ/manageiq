require 'trollop'
require 'pathname'
require 'appliance_console/env'
require 'appliance_console/utilities'
require 'appliance_console/logging'
require 'appliance_console/database_configuration'
require 'appliance_console/internal_database_configuration'
require 'appliance_console/external_database_configuration'
require 'appliance_console/external_httpd_authentication'
require 'appliance_console/service_group'
require 'appliance_console/key_configuration'
require 'appliance_console/certificate_authority'

# support for appliance_console methods
unless defined?(say)
  def say(*args)
    puts(*args)
  end
end

module ApplianceConsole
  class Cli
    attr_accessor :options

    def hostname
      options[:internal] ? "localhost" : options[:hostname]
    end

    def cahost
      return unless options[:ca]
      options[:cahost] || hostname || "localhost"
    end

    def local?(name = hostname)
      name.presence.in?(["localhost", "127.0.0.1", nil])
    end

    # currently, only creates the key for a local CA
    def key?
      options[:key] || (options[:ca] && local?(cahost))
    end

    def initialize(options = {})
      self.options = options
    end

    def disk_from_string(path)
      return if path.blank?
      path == "auto" ? disk : disk_by_path(path)
    end

    def disk
      LinuxAdmin::Disk.local.detect { |d| d.partitions.empty? }
    end

    def disk_by_path(path)
      LinuxAdmin::Disk.local.detect { |d| d.path == path }
    end

    def parse(args)
      args.shift if args.first == "--" # Handle when called through script/runner
      self.options = Trollop.options(args) do
        banner "Usage: appliance_console_cli [options]"

        opt :host,     "/etc/hosts name",    :type => :string,  :short => 'H'
        opt :region,   "Region Number",      :type => :integer, :short => "r"
        opt :internal, "Internal Database",                     :short => 'i'
        opt :hostname, "Database Hostname",  :type => :string,  :short => 'h'
        opt :username, "Database Username",  :type => :string,  :short => 'U', :default => "root"
        opt :password, "Database Password",  :type => :string,  :short => "p"
        opt :dbname,   "Database Name",      :type => :string,  :short => "d", :default => "vmdb_production"
        opt :ca,       "Setup CA",                              :short => 'c'
        opt :key,      "Create master key",  :type => :boolean, :short => "k"
        opt :cahost,   "CA host",            :type => :string,  :short => nil
        opt :company,  "CA company name",    :type => :string,  :short => nil, :default => "cfme demo"
        opt :causer,   "CA User",            :type => :string,                 :default => "root"
        opt :dbdisk,   "Database Disk Path", :type => :string
        opt :uninstall_ipa, "Uninstall IPA Client", :type => :boolean,         :default => false
        opt :ipaserver,  "IPA Server FQDN",  :type => :string
        opt :ipaprincipal,  "IPA Server principal", :type => :string,          :default => "admin"
        opt :ipapassword,   "IPA Server password",  :type => :string
      end
      Trollop.die :region, "needed when setting up a local database" if options[:region].nil? && hostname && local?
      self
    end

    def run
      Env[:host] = options[:host] if options[:host]
      create_key if key?
      set_ca if options[:ca]
      set_db if hostname
      uninstall_ipa if options[:uninstall_ipa]
      install_ipa if options[:ipaserver]
    end

    def set_db
      if local?(hostname)
        set_internal_db
      else
        set_external_db
      end
    end

    def set_internal_db
      config = ApplianceConsole::InternalDatabaseConfiguration.new({
        :database    => options[:dbname],
        :region      => options[:region],
        :username    => options[:username],
        :password    => options[:password],
        :interactive => false,
        :disk        => disk_from_string(options[:dbdisk])
      }.delete_if { |_n, v| v.nil? })

      # create partition, pv, vg, lv, ext4, update fstab, mount disk
      # initdb, relabel log directory for selinux, update configs,
      # start pg, create user, create db update the rails configuration,
      # verify, set up the database with region. activate does it all!
      config.activate

      # enable/start related services
      config.post_activation
    end

    def set_external_db
      config = ApplianceConsole::ExternalDatabaseConfiguration.new({
        :host        => options[:hostname],
        :database    => options[:dbname],
        :region      => options[:region],
        :username    => options[:username],
        :password    => options[:password],
        :interactive => false,
      }.delete_if { |_n, v| v.nil? })

      # call create_or_join_region (depends on region value)
      config.activate

      # enable/start related services
      config.post_activation
    end

    # force creating the key if user specifies -key
    # otherwise, only create if it does not exist locally
    def create_key
      KeyConfiguration.new.create_key(options[:key])
    end

    def set_ca
      ca = CertificateAuthority.new(Env[:host], Env[:ip])
      if local?(cahost)
        ca.local(options[:company]).create.run
      else
        ca.remote(cahost, options[:causer]).run
      end
    end

    def install_ipa
      config = ExternalHttpdAuthentication.new(
        options[:host] || Env["HOST"],
        :ipaserver => options[:ipaserver],
        :principal => options[:ipaprincipal],
        :password  => options[:ipapassword],
      )

      config.post_activation if config.activate
    end

    def uninstall_ipa
      config = ExternalHttpdAuthentication.new
      config.ipa_client_unconfigure if config.ipa_client_configured?
    end

    def self.parse(args)
      new.parse(args).run
    end
  end
end
