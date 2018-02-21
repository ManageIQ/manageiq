$LOAD_PATH << Rails.root.join("tools").to_s

require "miqldap_to_sssd"

describe MiqLdapToSssd::MiqLdapConfiguration do
  describe '#retrieve_initial_settings' do
    let(:settings) { {:tls_cacert => 'cert', :domain => "example.com"} }

    it 'raises an error when the basedn domain can not be determined' do
      expect(MiqLdapToSssd::LOGGER).to receive(:fatal)
      subject = described_class.new(settings.merge(:basedn => nil, :domain => nil))
      expect { subject.retrieve_initial_settings }.to raise_error(MiqLdapToSssd::MiqLdapConfigurationArgumentError)
    end

    it 'when mode is ldap and bind dn is nil raises an error' do
      expect(MiqLdapToSssd::LOGGER).to receive(:fatal)
      subject = described_class.new(settings.merge(:mode => 'ldap', :bind_pwd => nil))
      expect { subject.retrieve_initial_settings }.to raise_error(MiqLdapToSssd::MiqLdapConfigurationArgumentError)
    end

    it 'when mode is ldaps and bind dn is nil does not raises an error' do
      expect(MiqLdapToSssd::LOGGER).to_not receive(:fatal)
      subject = described_class.new(settings.merge(:mode => 'ldaps', :bind_dn => nil))
      expect { subject.retrieve_initial_settings }.to_not raise_error
    end

    it 'when mode is ldap and bind pwd is nil raises an error' do
      expect(MiqLdapToSssd::LOGGER).to receive(:fatal)
      subject = described_class.new(settings.merge(:mode => 'ldap', :bind_pwd => nil))
      expect { subject.retrieve_initial_settings }.to raise_error(MiqLdapToSssd::MiqLdapConfigurationArgumentError)
    end

    it 'when mode is ldaps and bind pwd is nil does not raises an error' do
      expect(MiqLdapToSssd::LOGGER).to_not receive(:fatal)
      subject = described_class.new(settings.merge(:mode => 'ldaps', :bind_pwd => nil))
      expect { subject.retrieve_initial_settings }.to_not raise_error
    end

    it 'does not modify domain if provided' do
      subject = described_class.new(settings.merge(:domain => "example.com"))
      expect(subject.retrieve_initial_settings[:domain]).to eq("example.com")
    end

    it 'sets domain from mixed case basedn' do
      subject = described_class.new(settings.merge(:basedn => "CN=Users,DC=Example,DC=COM"))
      expect(subject.retrieve_initial_settings[:domain]).to eq("example.com")
    end
  end
end
