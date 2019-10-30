require 'optimist'
require 'miq_config_sssd_ldap/cli'

module MiqConfigSssdLdap
  VALID_USER_TYPES = %w[dn-cn dn-uid userprincipalname mail samaccountname].freeze

  class CliConfig < Cli
    def parse(args)
      args.shift if args.first == "--" # Handle when called through script/runner

      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      self.opts = Optimist.options(args) do
        banner "Usage: ruby #{$PROGRAM_NAME} [opts]\n"

        opt :ldaphost,
            "LDAP Host Name",
            :short    => "H",
            :type     => :string,
            :required => true

        opt :ldapport,
            "LDAP Port",
            :short    => "P",
            :type     => :string,
            :required => false

        opt :user_type,
            "User Type for LDAP server use: dn-cn of dn-uid. For AD server use: userprincipalname, mail, samaccountname",
            :short    => "T",
            :type     => :string,
            :required => true

        opt :user_suffix,
            "User Suffix <user>@",
            :short    => "S",
            :type     => :string,
            :required => true

        opt :mode,
            "The Mode for the connection ldap or secure ldaps",
            :short    => "M",
            :type     => :string,
            :required => true

        opt :domain,
            "The domain name for the Base DN, e.g. example.com",
            :short    => "d",
            :default  => nil,
            :type     => :string,
            :required => true

        opt :bind_dn,
            "The Bind DN, credential to use to authenticate against LDAP e.g. cn=Manager,dc=example,dc=com",
            :short    => "b",
            :default  => nil,
            :type     => :string,
            :required => false

        opt :bind_pwd,
            "The password for the Bind DN.",
            :short    => "p",
            :default  => nil,
            :type     => :string,
            :required => false

        opt :ldap_role,
            "Get user groups from LDAP true or false",
            :short    => "g",
            :default  => false,
            :type     => :flag,
            :required => false

        opt :tls_cacert,
            "Path to certificate file",
            :short    => "c",
            :default  => nil,
            :type     => :string,
            :required => false

        opt :only_change_userids,
            "normalize the userids then exit",
            :short    => "n",
            :default  => false,
            :type     => :flag,
            :required => false

        opt :skip_post_conversion_userid_change,
            "Do the SSSD configuration but skip the normalizing of the userids",
            :short    => "s",
            :default  => false,
            :type     => :flag,
            :required => false
      end

      Optimist.die "#{opts[:mode]} is not a valid mode. Must be ldap or ldaps" unless mode_valid?
      Optimist.die "#{opts[:user_type]} is not a valid mode. Must be one of #{VALID_USER_TYPES}" unless user_type_valid?
      default_port_from_mode
      Optimist.die "#{opts[:ldaphost]}:#{opts[:ldapport]} is not open." unless ldaphost_and_ldapport_valid?
      opts[:ldaphost] = [opts[:ldaphost]] # Currently only supporting a single host from the command line.

      Optimist.die "bind_dn and bind_pwd are required when when Get user groups from ldap is true or mode is ldap." unless bind_dn_and_bind_pwd_valid?

      opts[:tls_cacertdir] = File.dirname(opts[:tls_cacert]) unless opts[:tls_cacert].nil?
      opts[:action] = "config"
      self.opts = opts.delete_if { |_n, v| v.nil? }
      LOGGER.debug("User provided settings: #{opts}")

      self
    end

    private

    def mode_valid?
      opts[:mode] == "ldaps" || opts[:mode] == "ldap"
    end

    def default_port_from_mode
      return unless opts[:ldapport].nil?

      opts[:ldapport] = 389 if opts[:mode] == "ldap"
      opts[:ldapport] = 636 if opts[:mode] == "ldaps"
    end

    def ldaphost_and_ldapport_valid?
      begin
        Timeout.timeout(1) do
          begin
            TCPSocket.new(opts[:ldaphost], opts[:ldapport]).close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            return false
          end
        end
      rescue Timeout::Error
        return false
      end

      false
    end

    def bind_dn_and_bind_pwd_valid?
      if opts[:mode] == "ldap" || opts[:ldap_role] == true
        return false if opts[:bind_dn].nil? || opts[:bind_pwd].nil?
      end
      true
    end

    def user_type_valid?
      return true if VALID_USER_TYPES.include?(opts[:user_type])

      false
    end
  end
end
