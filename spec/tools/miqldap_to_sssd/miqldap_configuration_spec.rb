$LOAD_PATH << Rails.root.join("tools", "miqldap_to_sssd").to_s

require "miqldap_configuration"

describe MiqLdapToSssd::MiqLdapConfiguration do
  before do
    stub_const("LOGGER", double)
    allow(LOGGER).to receive(:debug)
  end

  describe '#retrieve_initial_settings' do
    it 'raises an error when the basedn domain can not be determined' do
      expect(LOGGER).to receive(:fatal)
      subject = described_class.new(:basedn => nil, :basedn_domain => nil)
      expect { subject.retrieve_initial_settings }.to raise_error(MiqLdapToSssd::MiqLdapConfigurationArgumentError)
    end

    it 'does not modify basedn_domain if providedn' do
      subject = described_class.new(:basedn_domain => "example.com")
      expect(subject.retrieve_initial_settings[:basedn_domain]).to eq("example.com")
    end

    it 'sets basedn_domain from mixed case basedn' do
      subject = described_class.new(:basedn => "CN=Users,DC=Example,DC=COM")
      expect(subject.retrieve_initial_settings[:basedn_domain]).to eq("example.com")
    end
  end
end
