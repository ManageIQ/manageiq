require "rake"

RSpec.describe "EvmSettings", :type => :rake_task do
  let(:task_path) { "lib/tasks/evm_settings" }
  let(:keys) { ["/authentication/mode", "/authentication/httpd_role", "/authentication/sso_enabled", "/authentication/saml_enabled", "/authentication/oidc_enabled", "/authentication/local_login_disabled"] }

  describe ".get_keys" do
    context "gets the current keys" do
      it "when provider_type is none" do
        @settings_hash =
          {:authentication => {:mode                 => "database",
                               :httpd_role           => false,
                               :user_type            => "userprincipalname",
                               :amazon_key           => nil,
                               :oidc_enabled         => false,
                               :saml_enabled         => false,
                               :local_login_disabled => false,
                               :provider_type        => "none",
                               :sso_enabled          => false},
           :binary_blob    => {:purge_window_size    => 100}}

        allow(Settings).to receive(:to_hash).and_return(@settings_hash)
        expect(STDOUT).to receive(:puts).with("/authentication/mode=database")
        expect(STDOUT).to receive(:puts).with("/authentication/httpd_role=false")
        expect(STDOUT).to receive(:puts).with("/authentication/sso_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/saml_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/oidc_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/provider_type=none")
        expect(STDOUT).to receive(:puts).with("/authentication/local_login_disabled=false")
        EvmSettings.get_keys
      end

      it "when provider_type is oidc" do
        @settings_hash =
          {:authentication => {:mode                 => "httpd",
                               :httpd_role           => true,
                               :user_type            => "userprincipalname",
                               :amazon_key           => nil,
                               :oidc_enabled         => true,
                               :saml_enabled         => false,
                               :local_login_disabled => false,
                               :provider_type        => "oidc",
                               :sso_enabled          => false},
           :binary_blob    => {:purge_window_size    => 100}}

        allow(Settings).to receive(:to_hash).and_return(@settings_hash)
        expect(STDOUT).to receive(:puts).with("/authentication/mode=httpd")
        expect(STDOUT).to receive(:puts).with("/authentication/httpd_role=true")
        expect(STDOUT).to receive(:puts).with("/authentication/sso_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/saml_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/oidc_enabled=true")
        expect(STDOUT).to receive(:puts).with("/authentication/provider_type=oidc")
        expect(STDOUT).to receive(:puts).with("/authentication/local_login_disabled=false")
        EvmSettings.get_keys
      end

      it "when provider_type is saml" do
        @settings_hash =
          {:authentication => {:mode                 => "httpd",
                               :httpd_role           => true,
                               :user_type            => "userprincipalname",
                               :amazon_key           => nil,
                               :oidc_enabled         => false,
                               :saml_enabled         => true,
                               :local_login_disabled => false,
                               :provider_type        => "saml",
                               :sso_enabled          => false},
           :binary_blob    => {:purge_window_size    => 100}}

        allow(Settings).to receive(:to_hash).and_return(@settings_hash)
        expect(STDOUT).to receive(:puts).with("/authentication/mode=httpd")
        expect(STDOUT).to receive(:puts).with("/authentication/httpd_role=true")
        expect(STDOUT).to receive(:puts).with("/authentication/sso_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/saml_enabled=true")
        expect(STDOUT).to receive(:puts).with("/authentication/oidc_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/provider_type=saml")
        expect(STDOUT).to receive(:puts).with("/authentication/local_login_disabled=false")
        EvmSettings.get_keys
      end
    end
  end
end
