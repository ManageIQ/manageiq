$LOAD_PATH << Rails.root.join("tools", "miq_config_sssd_ldap").to_s

require "configure_appliance_settings"

RSpec.describe MiqConfigSssdLdap::ConfigureApplianceSettings do
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
      allow_any_instance_of(ConfigurationManagementMixin).to receive(:reload_all_server_settings)

      Vmdb::Settings.save!(miq_server, @auth_config)
      Settings.reload!

      described_class.new(:ldap_role => nil).configure

      settings = miq_server.settings
      expect(settings.fetch_path(:authentication, :mode)).to eq("httpd")
      expect(settings.fetch_path(:authentication, :ldap_role)).to eq(false)
      expect(settings.fetch_path(:authentication, :httpd_role)).to eq(true)
    end

    it 'sets httpd_role to ldap_role if ldap_role is specified' do
      # Needed to avoid pitfalls of not running on a live appliance with real settings
      allow_any_instance_of(ConfigurationManagementMixin).to receive(:reload_all_server_settings)

      Vmdb::Settings.save!(miq_server, @auth_config)
      Settings.reload!

      described_class.new(:ldap_role => false).configure

      settings = miq_server.settings
      expect(settings.fetch_path(:authentication, :mode)).to eq("httpd")
      expect(settings.fetch_path(:authentication, :ldap_role)).to eq(false)
      expect(settings.fetch_path(:authentication, :httpd_role)).to eq(false)
    end
  end
end
