$LOAD_PATH << Rails.root.join("tools").to_s

require "miqldap_to_sssd"
require "tempfile"
require "fileutils"
require 'auth_template_files'

describe MiqLdapToSssd::SssdConf do
  before do
    @spec_name = File.basename(__FILE__).split(".rb").first.freeze
  end

  describe '#onfigure' do
    let(:sssd_conf_erb) do
      <<-SSSD_CONF_ERB.strip_heredoc
        [domain/default]
        autofs_provider = ldap
        ldap_schema = rfc2307bis
        ldap_search_base = <%= ldapbasedn %>
        id_provider = ldap
        auth_provider = ldap
        chpass_provider = ldap
        ldap_uri = <%= ldapserver %>
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
      stub_const("MiqLdapToSssd::AuthTemplateFiles::TEMPLATE_DIR", @template_dir)

      @sssd_conf_dir = "#{@test_dir}/etc/sssd"
      @sssd_conf_file = "#{@sssd_conf_dir}/sssd.conf"
      FileUtils.mkdir_p @sssd_conf_dir
      @sssd_template_dir = FileUtils.mkdir_p("#{@template_dir}/#{@sssd_conf_dir}")[0]
      stub_const("MiqLdapToSssd::AuthTemplateFiles::SSSD_CONF_DIR", @sssd_conf_dir)
      stub_const("MiqLdapToSssd::SSSD_CONF_FILE", @sssd_conf_file)
    end

    after do
      FileUtils.rm_rf(@test_dir)
    end

    it 'will create the sssd config file if needed' do
      File.open("#{@sssd_template_dir}/sssd.conf.erb", "w") { |f| f.write(sssd_conf_erb) }

      described_class.new(@initial_settings)

      expect(File.read("#{@sssd_conf_dir}/sssd.conf")).to eq(sssd_conf)
    end

=begin
    it 'silently ignores missing KrbAuthRealms when creating the gssapi httpd config file' do
      File.open("#{@sssd_template_dir}/manageiq-external-auth.conf.erb", "w") do |f|
        f.write(manageiq_external_auth_gssapi_conf)
      end

      described_class.new(@initial_settings).configure
      expect(File.read("#{@sssd_conf_dir}/manageiq-external-auth.conf")).to eq(manageiq_external_auth_gssapi_conf)
    end

    it 'raises an error when a TEMPLATE file is missing' do
      FileUtils.rm_f("#{@pam_template_dir}/httpd-auth")
      expect(MiqLdapToSssd::LOGGER).to receive(:fatal)
      expect { described_class.new(@initial_settings).configure }.to raise_error(MiqLdapToSssd::ConfigureApacheError)
    end
=end
  end
end
