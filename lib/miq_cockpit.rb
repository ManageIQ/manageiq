require 'uri'
require 'awesome_spawn'

module MiqCockpit
  class WS
    DEFAULT_PORT = 9002

    # Used when the cockpit-ws worker is not enabled
    COCKPIT_PUBLIC_PORT = 9090

    MIQ_REDIRECT_URL = "/dashboard/cockpit_redirect".freeze
    COCKPIT_WS_PATH = '/usr/libexec/cockpit-ws'.freeze
    COCKPIT_SSH_PATH = '/usr/libexec/cockpit-ssh'.freeze

    attr_accessor :config_dir, :cockpit_dir

    def self.can_start_cockpit_ws?
      MiqEnvironment::Command.is_linux? &&
        !MiqEnvironment::Command.is_podified? &&
        File.exist?(COCKPIT_WS_PATH) &&
        File.exist?(COCKPIT_SSH_PATH)
    end

    def self.direct_url(address)
      URI::HTTP.build(:host => address,
                      :port => MiqCockpit::WS::COCKPIT_PUBLIC_PORT)
    end

    def self.server_address(miq_server)
      address = miq_server.ipaddress
      if miq_server.hostname && (::Settings.webservices.contactwith == 'hostname' || !address)
        address = miq_server.hostname
      end
      address
    end

    def self.current_ui_server?(miq_server)
      return false unless MiqServer.my_server == miq_server
      miq_server.has_active_userinterface
    end

    def self.url_from_server(miq_server, opts)
      opts ||= {}

      # Assume we are using apache unless we are the only server
      has_apache = current_ui_server?(miq_server) ? MiqEnvironment::Command.supports_apache? : true
      cls = has_apache ? URI::HTTPS : URI::HTTP
      cls.build(:host => server_address(miq_server),
                :port => has_apache ? nil : opts[:port] || DEFAULT_PORT,
                :path => MiqCockpit::ApacheConfig.url_root)
    end

    def self.url(miq_server, opts, address)
      return MiqCockpit::WS.direct_url(address) if miq_server.nil?

      opts ||= {}
      url = if opts[:external_url]
              URI.parse(opts[:external_url])
            else
              url_from_server(miq_server, opts)
            end

      # Make sure we have a path that ends in a /
      url.path = MiqCockpit::ApacheConfig.url_root if url.path.empty?
      url.path = "#{url.path}/" unless url.path.end_with?("/")

      # Add address to path if needed, note this is a path
      # not a querystring
      url.path = "#{url.path}=#{address}" if address
      url
    end

    def initialize(opts = {})
      @opts = opts || {}
      @config_dir = Rails.root.join("config").to_s
      @cockpit_conf_dir = File.join(@config_dir, "cockpit")
      FileUtils.mkdir_p(@cockpit_conf_dir)
    end

    def command(address)
      args = { :port => @opts[:port] || DEFAULT_PORT.to_s }
      if address
        args[:address] = address
      end
      args[:no_tls] = nil

      AwesomeSpawn.build_command_line(COCKPIT_WS_PATH, args)
    end

    def save_config
      fname = File.join(@cockpit_conf_dir, "cockpit.conf")
      update_config
      File.write(fname, @config)
      AwesomeSpawn.run!("restorecon -R -v #{@cockpit_conf_dir}")
    end

    def web_ui_url
      if @opts[:web_ui_url]
        url = URI.parse(@opts[:web_ui_url])
      else
        server = MiqRegion.my_region.try(:remote_ui_miq_server)
        unless server.nil?
          opts = { :port => 3000 }
          url = MiqCockpit::WS.url_from_server(server, opts)
        end
      end
      if url.nil?
        ret = MiqCockpit::WS::MIQ_REDIRECT_URL
      else
        # Force the dashboard redirect path
        url.path = MiqCockpit::WS::MIQ_REDIRECT_URL
        ret = url.to_s
      end
      ret
    end

    def update_config
      title = @opts[:title] || "ManageIQ Cockpit"

      login_command = File.join("/usr", "bin", "cockpit-auth-miq")

      @config = <<-END_OF_CONFIG
[Webservice]
LoginTitle = #{title}
UrlRoot = #{MiqCockpit::ApacheConfig::URL_ROOT}
ProtocolHeader = X-Forwarded-Proto

[Negotiate]
Action = none

[Basic]
Action = none

[Bearer]
Action = remote-login-ssh

[SSH-Login]
command = #{login_command}
authFD=10

[OAuth]
Url = #{web_ui_url}

END_OF_CONFIG
      @config
    end

    def setup_ssl
      dir = File.join(@cockpit_conf_dir, "ws-certs.d")
      FileUtils.mkdir_p(dir)
      cert = File.open('certs/server.cer') { |f| OpenSSL::X509::Certificate.new(f).to_pem }
      key = File.open('certs/server.cer.key') { |f| OpenSSL::PKey::RSA.new(f).to_pem }
      contents = [cert, key].join("\n")
      File.write(File.join(dir, "0-miq.cert"), contents)
    end
  end

  class ApacheConfig
    URL_ROOT = "cws".freeze

    def self.url_root
      "/#{URL_ROOT}/"
    end
  end
end
