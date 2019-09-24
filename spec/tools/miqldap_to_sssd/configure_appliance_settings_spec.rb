$LOAD_PATH << Rails.root.join("tools", "miqldap_to_sssd").to_s

require "configure_appliance_settings"

describe MiqLdapToSssd::ConfigureApplianceSettings do
  before do
    stub_const("LOGGER", double)
    allow(LOGGER).to receive(:debug)
    @auth_config = {
      :authentication => {:ldaphost   => ["my-ldaphost"],
                          :mode       => "ldap",
                          :httpd_role => false,
                          :ldap_role  => true}
    }
  end

  describe '#configure' do
    let!(:miq_server) { EvmSpecHelper.local_miq_server }
    before do
      stub_local_settings(miq_server)
    end

    it 'upates the authentication settings for external auth' do
      # Needed to avoid pitfalls of not running on a live appliance with real settings
      allow_any_instance_of(Vmdb::Settings).to receive(:activate)
      allow_any_instance_of(ConfigurationManagementMixin).to receive(:reload_all_server_settings)

      Vmdb::Settings.save!(miq_server, @auth_config)
      Settings.reload!

      described_class.new.configure

      settings = miq_server.settings
      expect(settings.fetch_path(:authentication, :mode)).to eq("httpd")
      expect(settings.fetch_path(:authentication, :ldap_role)).to eq(false)
      expect(settings.fetch_path(:authentication, :httpd_role)).to eq(true)
    end
  end
end
