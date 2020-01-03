$LOAD_PATH << Rails.root.join("tools").to_s

require "miq_config_sssd_ldap"

RSpec.describe MiqConfigSssdLdap::MiqLdapConfiguration do
  describe '#initialize' do
    let(:settings) { {:tls_cacert => 'cert', :domain => "example.com"} }
    let(:options) do
      {:action      => "config",
       :ldaphost    => "my-ldap-server",
       :user_type   => "dn-cn",
       :user_suffix => "ou=people,ou=prod,dc=example,dc=com",
       :mode        => "ldap",
       :domain      => "example.com",
       :bind_dn     => "cn=Manager,dc=example,dc=com",
       :bind_pwd    => "password"}
    end

    it 'does not merge current authentication setting with options when doing a fresh configuration' do
      expect_any_instance_of(described_class).to_not receive(:current_authentication_settings)
      described_class.new(options)
    end
  end

  describe '#retrieve_initial_settings' do
    let(:settings) { {:tls_cacert => 'cert', :domain => "example.com"} }

    it 'raises an error when the basedn domain can not be determined' do
      expect(MiqConfigSssdLdap::LOGGER).to receive(:fatal)
      subject = described_class.new(settings.merge(:basedn => nil, :domain => nil))
      expect { subject.retrieve_initial_settings }.to raise_error(MiqConfigSssdLdap::MiqLdapConfigurationArgumentError)
    end

    it 'when mode is ldap and bind dn is nil raises an error' do
      expect(MiqConfigSssdLdap::LOGGER).to receive(:fatal)
      subject = described_class.new(settings.merge(:mode => 'ldap', :bind_pwd => nil))
      expect { subject.retrieve_initial_settings }.to raise_error(MiqConfigSssdLdap::MiqLdapConfigurationArgumentError)
    end

    it 'when mode is ldaps and bind dn is nil does not raises an error' do
      expect(MiqConfigSssdLdap::LOGGER).to_not receive(:fatal)
      subject = described_class.new(settings.merge(:mode => 'ldaps', :bind_dn => nil))
      expect { subject.retrieve_initial_settings }.to_not raise_error
    end

    it 'when mode is ldap and bind pwd is nil raises an error' do
      expect(MiqConfigSssdLdap::LOGGER).to receive(:fatal)
      subject = described_class.new(settings.merge(:mode => 'ldap', :bind_pwd => nil))
      expect { subject.retrieve_initial_settings }.to raise_error(MiqConfigSssdLdap::MiqLdapConfigurationArgumentError)
    end

    it 'when mode is ldaps and bind pwd is nil does not raises an error' do
      expect(MiqConfigSssdLdap::LOGGER).to_not receive(:fatal)
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
