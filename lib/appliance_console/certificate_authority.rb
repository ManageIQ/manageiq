require 'fileutils'
require 'tempfile'
require 'appliance_console/principal'
require 'appliance_console/certificate'

module ApplianceConsole
  # configure ssl certificates for postgres communication
  # and appliance to appliance communications
  class CertificateAuthority
    TEMPLATES       = "/var/www/miq/system/TEMPLATE/"

    CFME_DIR        = "/var/www/miq/vmdb/certs"
    PSQL_CLIENT_DIR = "/root/.postgresql"

    # hostname of current machine
    attr_accessor :hostname
    # name of certificate authority
    attr_accessor :ca_name
    # true if we should configure postgres client
    attr_accessor :pgclient
    # true if we should configure postgres server
    attr_accessor :pgserver
    # true if we should configure api endpoint
    attr_accessor :api
    # true if we want to register the services with ipa
    attr_accessor :verbose

    def initialize(options = {})
      options.each { |n, v| public_send("#{n}=", v) }
      @ca_name ||= "ipa"
    end

    def activate
      valid_environment?

      configure_pgclient if pgclient
      configure_pgserver if pgserver
      configure_api if api

      status_string
    end

    def valid_environment?
      if ipa? && !ExternalHttpdAuthentication.ipa_client_configured?
        raise ArgumentError, "ipa client not configured"
      end

      raise ArgumentError, "hostname needs to be defined" unless hostname
    end

    def configure_pgclient
      unless File.exist?(PSQL_CLIENT_DIR)
        FileUtils.mkdir_p(PSQL_CLIENT_DIR, :mode => 0700)
        AwesomeSpawn.run!("/sbin/restorecon -R #{PSQL_CLIENT_DIR}")
      end

      self.pgclient = Certificate.new(
        :cert_filename => "#{PSQL_CLIENT_DIR}/postgresql.crt",
        :root_filename => "#{PSQL_CLIENT_DIR}/root.crt",
        :service       => "cloudforms",
        :extensions    => %w(client),
        :ca_name       => ca_name,
        :hostname      => hostname,
      ).request.status
    end

    def configure_pgserver
      cert = Certificate.new(
        :cert_filename => "#{CFME_DIR}/postgres.crt",
        :root_filename => "#{CFME_DIR}/root.crt",
        :service       => "postgresql",
        :extensions    => %w(server),
        :ca_name       => ca_name,
        :hostname      => hostname,
        :owner         => "postgres.postgres"
      ).request

      if cert.complete?
        say "configuring postgres to use certs"
        # only telling postgres to rewrite server configuration files
        # no need for username/password since not writing database.yml
        InternalDatabaseConfiguration.new(:ssl => true).configure_postgres
        LinuxAdmin::Service.new(ApplianceConsole::POSTGRESQL_SERVICE).restart
      end
      self.pgserver = cert.status
    end

    def configure_api
      Certificate.new(
        :cert_filename => "#{CFME_DIR}/apiclient.crt",
        :root_filename => "#{CFME_DIR}/root.crt",
        :service       => "cloudforms",
        :extensions    => %w(client),
        :ca_name       => ca_name,
        :hostname      => hostname,
        :owner         => "apache.apache"
      ).request
      cert = Certificate.new(
        :cert_filename => "#{CFME_DIR}/apiserver.crt",
        :root_filename => "#{CFME_DIR}/root.crt",
        :service       => "HTTP",
        :extensions    => %w(server),
        :ca_name       => ca_name,
        :hostname      => hostname,
        :owner         => "apache.apache",
      ).request
      if cert.complete?
        say "configuring apache to use certs"
        FileUtils.cp("#{TEMPLATES}/etc/httpd/conf.d/cfme-https-cert.conf", "/etc/httpd/conf.d/cfme-https-cert.conf")
        LinuxAdmin::Service.new("httpd").restart
      end
      self.api = cert.status
    end

    def status
      {"pgclient" => pgclient, "pgserver" => pgserver, "api" => api}.delete_if { |_n, v| !v }
    end

    def status_string
      status.collect { |n, v| "#{n}: #{v}" }.join " "
    end

    def complete?
      !status.values.detect { |v| v != ApplianceConsole::Certificate::STATUS_COMPLETE }
    end

    def ipa?
      ca_name == "ipa"
    end

    private

    def log
      say yield if verbose && block_given?
    end
  end
end
