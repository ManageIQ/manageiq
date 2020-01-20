$LOAD_PATH << Rails.root.join("tools").to_s

require "miq_config_sssd_ldap/cli_config"

RSpec.describe MiqConfigSssdLdap::CliConfig do
  before do
    @all_opts = :tls_cacert, :tls_cacertdir, :domain, :ldaphost, :ldapport, :user_type, :user_suffix, :mode,
                :bind_dn, :bind_pwd, :only_change_userids, :skip_post_conversion_userid_change
    @all_required_opts = %w[-H ldaphost -T dn-cn -S user_suffix -M ldap -d example.com -b cn=Manager,dc=example,dc=com -p password]
    allow(TCPSocket).to receive(:new).and_return(double(:close => nil))

    stub_const("LOGGER", double)
    allow(LOGGER).to receive(:debug)
  end

  describe "#parse" do
    it "should assign defaults" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(*@all_opts)
      expect(opts).to include(:ldapport => 389, :skip_post_conversion_userid_change => false)
    end

    it "should assign all required options when mode is ldap" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(*@all_opts)
      expect(opts).to eq(:bind_dn                            => "cn=Manager,dc=example,dc=com",
                         :bind_pwd                           => "password",
                         :domain                             => "example.com",
                         :ldaphost                           => ["ldaphost"],
                         :ldapport                           => 389,
                         :mode                               => "ldap",
                         :only_change_userids                => false,
                         :skip_post_conversion_userid_change => false,
                         :user_suffix                        => "user_suffix",
                         :user_type                          => "dn-cn")
    end

    it "should assign default non-secure ldapport" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(:ldapport)
      expect(opts).to eq(:ldapport => 389)
    end

    it "should assign default secure ldapport" do
      opts = described_class.new.parse(@all_required_opts - %w[-M ldap] + %w[-M ldaps]).opts.slice(:ldapport)
      expect(opts).to eq(:ldapport => 636)
    end

    it "should parse ldaphost" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(:ldaphost)
      expect(opts).to eq(:ldaphost => ["ldaphost"])
    end

    it "should parse ldapport" do
      opts = described_class.new.parse(@all_required_opts + %w[-P 8675309]).opts.slice(:ldapport)
      expect(opts).to eq(:ldapport => "8675309")
    end

    it "should parse user_type" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(:user_type)
      expect(opts).to eq(:user_type => "dn-cn")
    end

    it "should parse user_suffix" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(:user_suffix)
      expect(opts).to eq(:user_suffix => "user_suffix")
    end

    it "should parse mode" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(:mode)
      expect(opts).to eq(:mode => "ldap")
    end

    it "should parse base DN domain names" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(:domain)
      expect(opts).to eq(:domain => "example.com")
    end

    it "should parse bind DN" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(:bind_dn)
      expect(opts).to eq(:bind_dn => "cn=Manager,dc=example,dc=com")
    end

    it "should parse bind pwd" do
      opts = described_class.new.parse(@all_required_opts).opts.slice(:bind_pwd)
      expect(opts).to eq(:bind_pwd => "password")
    end

    it "should parse TLS cacert path and directory" do
      opts = described_class.new.parse(@all_required_opts + %w[-c /a/path/to/a/cacert]).opts.slice(:tls_cacert, :tls_cacertdir)
      expect(opts).to eq(:tls_cacert => "/a/path/to/a/cacert", :tls_cacertdir => "/a/path/to/a")
    end

    it "can skip updating the userids after the conversion" do
      opts = described_class.new.parse(@all_required_opts + %w[-s]).opts.slice(*@all_opts)
      expect(opts).to include(:skip_post_conversion_userid_change => true)
    end

    context "When mode is ldap" do
      it "requires bind_dn" do
        expect(Optimist).to receive(:die)
        described_class.new.parse(@all_required_opts - %w[-b cn=Manager,dc=example,dc=com])
      end

      it "requires bind_pwd" do
        expect(Optimist).to receive(:die)
        described_class.new.parse(@all_required_opts - %w[-p password])
      end
    end

    context "When ldap_role is true" do
      before do
        @ldap_role_ldaps_opts = @all_required_opts - %w[-M ldap] + %w[-M ldaps -g]
      end

      it "requires bind_dn" do
        expect(Optimist).to receive(:die)
        described_class.new.parse(@ldap_role_ldaps_opts - %w[-b cn=Manager,dc=example,dc=com])
      end

      it "requires bind_pwd" do
        expect(Optimist).to receive(:die)
        described_class.new.parse(@ldap_role_ldaps_opts - %w[-p password])
      end
    end
  end
end
