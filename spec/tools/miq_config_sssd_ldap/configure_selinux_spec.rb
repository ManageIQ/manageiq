$LOAD_PATH << Rails.root.join("tools").to_s

require "miq_config_sssd_ldap"

RSpec.describe MiqConfigSssdLdap::ConfigureSELinux do
  describe '#configure' do
    before do
      @initial_settings = {:ldapport => '22'}
      @success = double(:command_line => "semanage", :failure? => false)
      @semanage_params = {nil => "port", :a => nil, :t => "ldap_port_t", :p => %w[tcp 22]}
      @failure1 = double(:command_line => "semanage", :failure? => true, :error => "malfunction already defined")
      @failure2 = double(:command_line => "semanage", :failure? => true, :error => "malfunction")
    end

    it 'invokes semanage and setsebool with valid parameters' do
      expect(AwesomeSpawn).to receive(:run).once.with("semanage", :params => @semanage_params).and_return(@success)
      expect(AwesomeSpawn).to receive(:run).once.with("setsebool", :params => {:P=>%w[allow_httpd_mod_auth_pam on]}).and_return(@success)
      expect(AwesomeSpawn).to receive(:run).once.with("setsebool", :params => {:P=>%w[httpd_dbus_sssd on]}).and_return(@success)
      expect { described_class.new(@initial_settings).configure }.to_not raise_error
    end

    it 'handles semanage already defined result' do
      expect(MiqConfigSssdLdap::LOGGER).to_not receive(:fatal)
      expect(AwesomeSpawn).to receive(:run).once.and_return(@failure1)
      expect(AwesomeSpawn).to receive(:run).once.with("setsebool", :params => {:P=>%w[allow_httpd_mod_auth_pam on]}).and_return(@success)
      expect(AwesomeSpawn).to receive(:run).once.with("setsebool", :params => {:P=>%w[httpd_dbus_sssd on]}).and_return(@success)
      expect { described_class.new(@initial_settings).configure }.to_not raise_error
    end

    it 'handles semanage failures' do
      expect(MiqConfigSssdLdap::LOGGER).to receive(:fatal).with("semanage failed with: malfunction")
      expect(AwesomeSpawn).to receive(:run).and_return(@failure2)
      expect { described_class.new(@initial_settings).configure }.to raise_error(MiqConfigSssdLdap::ConfigureSELinuxError)
    end

    it 'handles setsebool failures' do
      expect(MiqConfigSssdLdap::LOGGER).to receive(:fatal).with("setsebool failed with: malfunction")
      expect(AwesomeSpawn).to receive(:run).once.with("semanage", :params => @semanage_params).and_return(@success)

      expect(AwesomeSpawn).to receive(:run)
        .and_return(double(:command_line => "setsebool", :failure? => true, :error => "malfunction"))
      expect { described_class.new(@initial_settings).configure }.to raise_error(MiqConfigSssdLdap::ConfigureSELinuxError)
    end
  end
end
