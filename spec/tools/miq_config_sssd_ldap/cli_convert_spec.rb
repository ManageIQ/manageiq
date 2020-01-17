$LOAD_PATH << Rails.root.join("tools").to_s

require "miq_config_sssd_ldap/cli_convert"

RSpec.describe MiqConfigSssdLdap::CliConvert do
  before do
    @all_opts = :tls_cacert, :tls_cacertdir, :domain, :only_change_userids, :skip_post_conversion_userid_change
    stub_const("LOGGER", double)
    allow(LOGGER).to receive(:debug)
  end

  describe "#parse" do
    it "should assign defaults" do
      opts = described_class.new.parse([]).opts.slice(*@all_opts)
      expect(opts).to eq(:only_change_userids => false, :skip_post_conversion_userid_change => false)
    end

    it "should parse base DN domain names" do
      opts = described_class.new.parse(%w[-d example.com]).opts.slice(:domain)
      expect(opts).to eq(:domain => "example.com")
    end

    it "should parse bind DN" do
      opts = described_class.new.parse(%w[-b cn=Manager,dc=example,dc=com]).opts.slice(:bind_dn)
      expect(opts).to eq(:bind_dn => "cn=Manager,dc=example,dc=com")
    end

    it "should parse bind pwd" do
      opts = described_class.new.parse(%w[-p password]).opts.slice(:bind_pwd)
      expect(opts).to eq(:bind_pwd => "password")
    end

    it "should parse TLS cacert path and directory" do
      opts = described_class.new.parse(%w[-c /a/path/to/a/cacert]).opts.slice(:tls_cacert, :tls_cacertdir)
      expect(opts).to eq(:tls_cacert => "/a/path/to/a/cacert", :tls_cacertdir => "/a/path/to/a")
    end

    it "can only updating the userids" do
      opts = described_class.new.parse(%w[-n]).opts.slice(*@all_opts)
      expect(opts).to eq(:only_change_userids => true, :skip_post_conversion_userid_change => false)
    end

    it "can skip updating the userids after the conversion" do
      opts = described_class.new.parse(%w[-s]).opts.slice(*@all_opts)
      expect(opts).to eq(:only_change_userids => false, :skip_post_conversion_userid_change => true)
    end
  end
end
