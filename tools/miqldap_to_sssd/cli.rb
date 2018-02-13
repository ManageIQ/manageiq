require 'trollop'

module MiqLdapToSssd
  class Cli
    attr_accessor :options

    def parse(args)
      args.shift if args.first == "--" # Handle when called through script/runner

      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      self.options = Trollop.options(args) do
        banner "Usage: ruby #{$PROGRAM_NAME} [options]\n"

        opt :basedn_domain,
            "The Base DN domain name, e.g. example.com",
            :short   => "d",
            :default => nil,
            :type    => :string

        opt :bind_dn,
            "The Bind DN, credential to use to authenticate against LDAP e.g. cn=Manager,dc=example,dc=com",
            :short   => "b",
            :default => nil,
            :type    => :string

        opt :bind_pwd,
            "The Base DN domain name, e.g. example.com",
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

        opt :skip_post_coversion_userid_change,
            "Do the MiqLdap to SSSD conversion but skip the normalizing of the userids",
            :short   => "s",
            :default => false,
            :type    => :flag
      end

      options[:tls_cacertdir] = File.dirname(options[:tls_cacert]) unless options[:tls_cacert].nil?
      self.options = options.delete_if { |_n, v| v.nil? }
      LOGGER.debug("User provided settings: #{options}")

      self
    end

    def run
      Converter.new(options).run
    end

    def self.run(args)
      new.parse(args).run
    end
  end
end
