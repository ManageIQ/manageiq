$LOAD_PATH << Rails.root.join("tools").to_s

require "miqldap_to_sssd"

describe MiqLdapToSssd::AuthConfig do
  describe '#run_auth_config' do
    before do
      @initial_settings = {:mode => "bob", :ldaphost => ["hostname"], :ldapport => 22}
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
      described_class.new(@initial_settings).run_auth_config
    end

    it 'handles authconfig failures' do
      expect(MiqLdapToSssd::LOGGER).to receive(:fatal)
      expect(AwesomeSpawn).to receive(:run)
        .and_return(double(:command_line => "authconfig", :failure? => true, :error => "malfunction"))
      expect { described_class.new(@initial_settings).run_auth_config }.to raise_error(MiqLdapToSssd::AuthConfigError)
    end
  end
end
