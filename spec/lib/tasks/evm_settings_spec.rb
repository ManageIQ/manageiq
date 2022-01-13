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
           :prototype      => {:messaging_type       => "krabby patties"},
           :binary_blob    => {:purge_window_size    => 100}}

        allow(Settings).to receive(:to_hash).and_return(@settings_hash)
        expect(STDOUT).to receive(:puts).with("/authentication/mode=database")
        expect(STDOUT).to receive(:puts).with("/authentication/httpd_role=false")
        expect(STDOUT).to receive(:puts).with("/authentication/sso_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/saml_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/oidc_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/provider_type=none")
        expect(STDOUT).to receive(:puts).with("/authentication/local_login_disabled=false")
        expect(STDOUT).to receive(:puts).with("/prototype/messaging_type=krabby patties")
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
           :prototype      => {:messaging_type       => "krabby patties"},
           :binary_blob    => {:purge_window_size    => 100}}

        allow(Settings).to receive(:to_hash).and_return(@settings_hash)
        expect(STDOUT).to receive(:puts).with("/authentication/mode=httpd")
        expect(STDOUT).to receive(:puts).with("/authentication/httpd_role=true")
        expect(STDOUT).to receive(:puts).with("/authentication/sso_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/saml_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/oidc_enabled=true")
        expect(STDOUT).to receive(:puts).with("/authentication/provider_type=oidc")
        expect(STDOUT).to receive(:puts).with("/authentication/local_login_disabled=false")
        expect(STDOUT).to receive(:puts).with("/prototype/messaging_type=krabby patties")
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
           :prototype      => {:messaging_type       => "krabby patties"},
           :binary_blob    => {:purge_window_size    => 100}}

        allow(Settings).to receive(:to_hash).and_return(@settings_hash)
        expect(STDOUT).to receive(:puts).with("/authentication/mode=httpd")
        expect(STDOUT).to receive(:puts).with("/authentication/httpd_role=true")
        expect(STDOUT).to receive(:puts).with("/authentication/sso_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/saml_enabled=true")
        expect(STDOUT).to receive(:puts).with("/authentication/oidc_enabled=false")
        expect(STDOUT).to receive(:puts).with("/authentication/provider_type=saml")
        expect(STDOUT).to receive(:puts).with("/authentication/local_login_disabled=false")
        expect(STDOUT).to receive(:puts).with("/prototype/messaging_type=krabby patties")
        EvmSettings.get_keys
      end
    end
  end

  describe "ALLOWED_KEYS" do
    it "has the correct keys" do
      @settings_keys = ["/authentication/httpd_role", "/authentication/local_login_disabled", "/authentication/mode", "/authentication/oidc_enabled",
                        "/authentication/provider_type", "/authentication/saml_enabled", "/authentication/sso_enabled", "/prototype/messaging_type"].sort

      expect(EvmSettings::ALLOWED_KEYS.sort).to eq(@settings_keys)
    end
  end

  describe "#value_to_str (private)" do
    it "keeps strings as strings" do
      expect(EvmSettings.send(:value_to_str, "AbCd")).to eq("AbCd")
    end

    it "converts true boolean" do
      expect(EvmSettings.send(:value_to_str, true)).to eq("true")
      expect(EvmSettings.send(:value_to_str, "true")).to eq("true")
      expect(EvmSettings.send(:value_to_str, "TRUE")).to eq("true")
    end

    it "converts false boolean" do
      expect(EvmSettings.send(:value_to_str, false)).to eq("false")
      expect(EvmSettings.send(:value_to_str, "false")).to eq("false")
      expect(EvmSettings.send(:value_to_str, "FALSE")).to eq("false")
    end

    it "keeps nil as nil" do
      expect(EvmSettings.send(:value_to_str, nil)).to eq(nil)
    end
  end

  describe "#str_to_value (private)" do
    it "keeps strings as strings" do
      expect(EvmSettings.send(:str_to_value, "AbCd")).to eq("AbCd")
    end

    it "converts true boolean" do
      expect(EvmSettings.send(:str_to_value, "true")).to eq(true)
      expect(EvmSettings.send(:str_to_value, "TRUE")).to eq(true)
    end

    it "converts false boolean" do
      expect(EvmSettings.send(:str_to_value, false)).to eq(false)
      expect(EvmSettings.send(:str_to_value, "false")).to eq(false)
      expect(EvmSettings.send(:str_to_value, "FALSE")).to eq(false)
    end

    it "keeps nil as nil" do
      expect(EvmSettings.send(:str_to_value, "nil")).to eq(nil)
      expect(EvmSettings.send(:str_to_value, nil)).to eq(nil)
    end
  end
end
