$LOAD_PATH << Rails.root.join("tools").to_s

require "miq_config_sssd_ldap"

RSpec.describe MiqConfigSssdLdap::AuthEstablish do
  describe '#run_auth_establish' do
    before do
      @initial_settings = {:mode => "bob", :ldaphost => ["hostname"], :ldapport => 22}
      @auth_establish = described_class.new(@initial_settings)
    end

    context "when authselect is available" do
      before do
        allow(@auth_establish).to receive(:authselect_found?).and_return(true)
      end

      it 'invokes authconfig with valid parameters' do
        expect(AwesomeSpawn).to receive(:run)
          .with("authselect select sssd --force")
          .and_return(double(:command_line => "authselect", :failure? => false))
        @auth_establish.run_auth_establish
      end

      it 'handles authconfig failures' do
        expect(MiqConfigSssdLdap::LOGGER).to receive(:fatal)
        expect(AwesomeSpawn).to receive(:run)
          .and_return(double(:command_line => "authselect", :failure? => true, :error => "malfunction"))
        expect { @auth_establish.run_auth_establish }.to raise_error(MiqConfigSssdLdap::AuthEstablishError)
      end
    end

    context "when authselect is not available" do
      before do
        allow(@auth_establish).to receive(:authselect_found?).and_return(false)
      end

      it 'invokes authconfig with valid parameters' do
        expect(AwesomeSpawn).to receive(:run)
          .with("authconfig",
                :params => { :ldapserver=        => "bob://hostname:22",
                             :ldapbasedn=        => nil,
                             :enablesssd         => nil,
                             :enablesssdauth     => nil,
                             :enablelocauthorize => nil,
                             :enableldap         => nil,
                             :enableldapauth     => nil,
                             :disableldaptls     => nil,
                             :enablerfc2307bis   => nil,
                             :enablecachecreds   => nil,
                             :update             => nil})
          .and_return(double(:command_line => "authconfig", :failure? => false))
        @auth_establish.run_auth_establish
      end

      it 'handles authconfig failures' do
        expect(MiqConfigSssdLdap::LOGGER).to receive(:fatal)
        expect(AwesomeSpawn).to receive(:run)
          .and_return(double(:command_line => "authconfig", :failure? => true, :error => "malfunction"))
        expect { @auth_establish.run_auth_establish }.to raise_error(MiqConfigSssdLdap::AuthEstablishError)
      end
    end
  end
end
