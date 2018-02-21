$LOAD_PATH << Rails.root.join("tools").to_s

require "miqldap_to_sssd"
require "tempfile"
require "fileutils"

describe MiqLdapToSssd::ConfigureApache do
  before do
    @spec_name = File.basename(__FILE__).split(".rb").first.freeze
  end

  describe '#onfigure' do
    let(:manageiq_pam_conf) do
      <<-EOT.strip_heredoc
        manageiq pam conf data
      EOT
    end

    let(:manageiq_remote_user_conf) do
      <<-EOT.strip_heredoc
        manageiq remote user conf data
      EOT
    end

    let(:manageiq_external_auth_conf) do
      <<-EOT.strip_heredoc
        KrbMethodK5Passwd  Off
        KrbAuthRealms      <%= realm %>
        Krb5KeyTab         /etc/http.keytab
      EOT
    end

    let(:expected_manageiq_external_auth_conf) do
      <<-EOT.strip_heredoc
        KrbMethodK5Passwd  Off
        KrbAuthRealms      bob.your.uncle.com
        Krb5KeyTab         /etc/http.keytab
      EOT
    end

    before do
      @initial_settings = {:domain => "bob.your.uncle.com"}

      @test_dir = "#{Dir.tmpdir}/#{@spec_name}"
      @template_dir = "#{@test_dir}/TEMPLATE"
      stub_const("MiqLdapToSssd::ConfigureApache::TEMPLATE_DIR", @template_dir)

      @httpd_conf_dir = "#{@test_dir}/etc/httpd/conf.d"
      FileUtils.mkdir_p @httpd_conf_dir
      @httpd_template_dir = FileUtils.mkdir_p("#{@template_dir}/#{@httpd_conf_dir}")[0]
      stub_const("MiqLdapToSssd::ConfigureApache::HTTPD_CONF_DIR", @httpd_conf_dir)

      @pam_conf_dir = "#{@test_dir}/etc/pam.d"
      FileUtils.mkdir_p @pam_conf_dir
      @pam_template_dir = FileUtils.mkdir_p("#{@template_dir}/#{@pam_conf_dir}")[0]
      stub_const("MiqLdapToSssd::ConfigureApache::PAM_CONF_DIR", @pam_conf_dir)

      File.open("#{@pam_template_dir}/httpd-auth", "w") { |f| f.write(manageiq_pam_conf) }
      File.open("#{@httpd_template_dir}/manageiq-remote-user.conf", "w") { |f| f.write(manageiq_remote_user_conf) }
      File.open("#{@httpd_template_dir}/manageiq-external-auth.conf.erb", "w") do |f|
        f.write(manageiq_external_auth_conf)
      end
    end

    after do
      FileUtils.rm_rf(@test_dir)
    end

    it 'creates the httpd and pam config files' do
      described_class.new(@initial_settings).configure
      expect(File.read("#{@pam_conf_dir}/httpd-auth")).to eq(manageiq_pam_conf)
      expect(File.read("#{@httpd_conf_dir}/manageiq-remote-user.conf")).to eq(manageiq_remote_user_conf)
      expect(File.read("#{@httpd_conf_dir}/manageiq-external-auth.conf")).to eq(expected_manageiq_external_auth_conf)
    end

    it 'raises an error when a TEMPLATE file is missing' do
      FileUtils.rm_f("#{@pam_template_dir}/httpd-auth")
      expect(MiqLdapToSssd::LOGGER).to receive(:fatal)
      expect { described_class.new(@initial_settings).configure }.to raise_error(MiqLdapToSssd::ConfigureApacheError)
    end

    it 'raises an error when KrbAuthRealms is missing from manageiq-external-auth.conf' do
      File.open("#{@httpd_template_dir}/manageiq-external-auth.conf.erb", "w") { |f| f.write("hello walls") }
      expect(MiqLdapToSssd::LOGGER).to receive(:fatal)
      expect { described_class.new(@initial_settings).configure }.to raise_error(MiqLdapToSssd::ConfigureApacheError)
    end
  end
end
