$LOAD_PATH << Rails.root.join("tools").to_s

require "miq_config_sssd_ldap"
require "tempfile"
require "fileutils"
require 'auth_template_files'

RSpec.describe MiqConfigSssdLdap::ConfigureSssdRules do
  before do
    @spec_name = File.basename(__FILE__).split(".rb").first.freeze
  end

  describe '#disable_tls' do
    let(:disable_tls_conf) do
      <<-CFG_RULES_CONF.strip_heredoc
        option = ldap_auth_disable_tls_never_use_in_production
      CFG_RULES_CONF
    end

    before do
      @test_dir = "#{Dir.tmpdir}/#{@spec_name}"
      stub_const("MiqConfigSssdLdap::ConfigureSssdRules::CFG_RULES_FILE", @test_dir)
    end

    after do
      FileUtils.rm_rf(@test_dir)
    end

    it 'appends the disable tls option to the sssd config file' do
      described_class.disable_tls
      expect(File.read(@test_dir)).to eq(disable_tls_conf)
    end
  end
end
