require 'optimist'
require 'miq_config_sssd_ldap/cli'

module MiqConfigSssdLdap
  class CliConvert < Cli
    def parse(args)
      args.shift if args.first == "--" # Handle when called through script/runner

      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      self.opts = Optimist.options(args) do
        banner "Usage: ruby #{$PROGRAM_NAME} [opts]\n"

        opt :domain,
            "The domain name for the Base DN, e.g. example.com",
            :short   => "d",
            :default => nil,
            :type    => :string

        opt :bind_dn,
            "The Bind DN, credential to use to authenticate against LDAP e.g. cn=Manager,dc=example,dc=com",
            :short   => "b",
            :default => nil,
            :type    => :string

        opt :bind_pwd,
            "The password for the Bind DN.",
            :short   => "p",
            :default => nil,
            :type    => :string

        opt :tls_cacert,
            "Path to certificate file",
            :short   => "c",
            :default => nil,
            :type    => :string

        opt :only_change_userids,
            "normalize the userids then exit",
            :short   => "n",
            :default => false,
            :type    => :flag

        opt :skip_post_conversion_userid_change,
            "Do the MiqLdap to SSSD conversion but skip the normalizing of the userids",
            :short   => "s",
            :default => false,
            :type    => :flag
      end

      opts[:tls_cacertdir] = File.dirname(opts[:tls_cacert]) unless opts[:tls_cacert].nil?
      opts[:action] = "convert"
      self.opts = opts.delete_if { |_n, v| v.nil? }
      LOGGER.debug("User provided settings: #{opts}")

      self
    end
  end
end
