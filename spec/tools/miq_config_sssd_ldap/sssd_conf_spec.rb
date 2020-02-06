$LOAD_PATH << Rails.root.join("tools").to_s

require "miq_config_sssd_ldap"
require "tempfile"
require "fileutils"
require "auth_template_files"

RSpec.describe MiqConfigSssdLdap::SssdConf do
  before do
    @spec_name = File.basename(__FILE__).split(".rb").first.freeze
  end

  describe '#configure' do
    let(:sssd_conf_erb) do
      <<-SSSD_CONF_ERB.strip_heredoc
        [domain/default]
        autofs_provider = ldap
        ldap_schema = rfc2307bis
        ldap_search_base = <%= ldap_search_base %>
        id_provider = ldap
        auth_provider = ldap
        chpass_provider = ldap
        ldap_uri = <%= ldap_uri %>
        ldap_id_use_start_tls = False
        cache_credentials = True
        ldap_tls_cacertdir = /etc/openldap/cacerts
        [sssd]
        services = nss, pam, autofs
        domains = default
        [pam]
        [ifp]
      SSSD_CONF_ERB
    end

    let(:sssd_conf) do
      <<-SSSD_CONF_ERB.strip_heredoc
        [domain/default]
        autofs_provider = ldap
        ldap_schema = rfc2307bis
        ldap_search_base = my_basedn
        id_provider = ldap
        auth_provider = ldap
        chpass_provider = ldap
        ldap_uri = ldap://ldap_host:2
        ldap_id_use_start_tls = False
        cache_credentials = True
        ldap_tls_cacertdir = /etc/openldap/cacerts
        [sssd]
        services = nss, pam, autofs
        domains = default
        [pam]
        [ifp]
      SSSD_CONF_ERB
    end

    before do
      @initial_settings = {:mode => "ldap", :ldaphost => ["ldap_host"], :ldapport => "2", :basedn => "my_basedn" }

      @test_dir = "#{Dir.tmpdir}/#{@spec_name}"
      @template_dir = "#{@test_dir}/TEMPLATE"
      stub_const("MiqConfigSssdLdap::AuthTemplateFiles::TEMPLATE_DIR", @template_dir)

      @sssd_conf_dir = "#{@test_dir}/etc/sssd"
      @sssd_conf_file = "#{@sssd_conf_dir}/sssd.conf"
      FileUtils.mkdir_p @sssd_conf_dir
      @sssd_template_dir = FileUtils.mkdir_p("#{@template_dir}/#{@sssd_conf_dir}")[0]
      stub_const("MiqConfigSssdLdap::AuthTemplateFiles::SSSD_CONF_DIR", @sssd_conf_dir)
      stub_const("MiqConfigSssdLdap::SSSD_CONF_FILE", @sssd_conf_file)
    end

    after do
      FileUtils.rm_rf(@test_dir)
    end

    it 'will create the sssd config file if needed' do
      File.open("#{@sssd_template_dir}/sssd.conf.erb", "w") { |f| f.write(sssd_conf_erb) }

      described_class.new(@initial_settings)

      expect(File.read("#{@sssd_conf_dir}/sssd.conf")).to eq(sssd_conf)
    end
  end
end
