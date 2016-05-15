describe Authentication do
  it ".encrypted_columns" do
    expect(described_class.encrypted_columns).to include('password', 'auth_key')
  end

  context "with miq events seeded" do
    before(:each) do
      MiqEventDefinition.seed
    end

    it "should create the authentication events and event sets" do
      events = %w(ems_auth_changed ems_auth_valid ems_auth_invalid ems_auth_unreachable ems_auth_incomplete ems_auth_error
                  host_auth_changed host_auth_valid host_auth_invalid host_auth_unreachable host_auth_incomplete host_auth_error)
      events.each { |event| expect(MiqEventDefinition.exists?(:name => event)).to be_truthy }
      expect(MiqEventDefinitionSet.exists?(:name => 'auth_validation')).to be_truthy
    end
  end

  context "with an authentication" do
    let(:pwd_plain) { "smartvm" }
    let(:pwd_encrypt) { MiqPassword.encrypt(pwd_plain) }
    let(:auth) { FactoryGirl.create(:authentication, :password => pwd_plain) }

    it "should return decrypted password" do
      expect(auth.password).to eq(pwd_plain)
    end

    it "should store encrypted password" do
      expect(Authentication.where(:password => pwd_plain).count).to eq(0)
      expect(auth.reload.password).to eq(pwd_plain)
    end
  end

  context "authentication yml generation" do
    it "parse allow all correctly" do
      authentication = FactoryGirl.create(:authentication_allow_all)
      expect(authentication.ansible_config_format).to eq('name'      => "example_name",
                                                         'login'     => "true",
                                                         'challenge' => "true",
                                                         'kind'      => "AllowAllPasswordIdentityProvider")
    end

    it "parse github correctly" do
      authentication = FactoryGirl.create(:authentication_github)
      expect(authentication.ansible_config_format).to eq("name"                 => "example_name",
                                                         "login"                => "true",
                                                         "challenge"            => "false",
                                                         "kind"                 => "GitHubIdentityProvider",
                                                         "clientID"             => "testuser",
                                                         "clientSecret"         => "secret",
                                                         "github_organizations" => ["github_organizations"])
    end

    it "parse google correctly" do
      authentication = FactoryGirl.create(:authentication_google)
      expect(authentication.ansible_config_format).to eq("name"         => "example_name",
                                                         "login"        => "true",
                                                         "challenge"    => "false",
                                                         "kind"         => "GoogleIdentityProvider",
                                                         "clientID"     => "testuser",
                                                         "clientSecret" => "secret",
                                                         "hostedDomain" => "google_hosted_domain")
    end

    it "parse htpasswd correctly" do
      authentication = FactoryGirl.create(:authentication_htpasswd)
      expect(authentication.ansible_config_format).to eq("name"      => "example_name",
                                                         "login"     => "true",
                                                         "challenge" => "true",
                                                         "kind"      => "HTPasswdPasswordIdentityProvider",
                                                         "filename"  => "/etc/origin/master/htpasswd")
    end

    it "parse ldap correctly" do
      authentication = FactoryGirl.create(:authentication_ldap)
      expect(authentication.ansible_config_format).to eq("name" => "example_name", "login" => "true",
                                                          "challenge" => "true",
                                                          "kind" => "LDAPPasswordIdentityProvider",
                                                          "attributes" => {"id"                => ["ldap_id"],
                                                                           "email"             => ["ldap_email"],
                                                                           "name"              => ["ldap_name"],
                                                                           "preferredUsername" => ["ldap_preferred_user_name"]},
                                                          "bindDN" => "ldap_bind_dn",
                                                          "bindPassword" => "secret",
                                                          "ca" => "certificate_authority",
                                                          "insecure" => "true",
                                                          "url" => "ldap_url")
    end

    it "parse openID correctly" do
      authentication = FactoryGirl.create(:authentication_open_id)
      expect(authentication.ansible_config_format).to eq("name"                               => "example_name",
                                                         "login"                              => "true",
                                                         "challenge"                          => "false",
                                                         "kind"                               => "OpenIDIdentityProvider",
                                                         "clientID"                           => "testuser",
                                                         "clientSecret"                       => "secret",
                                                         "claims"                             => {"id"=>"open_id_sub_claim"},
                                                         "urls"                               => {"authorize" => "open_id_authorization_endpoint",
                                                                                                  "toekn"     => "open_id_token_endpoint"},
                                                         "open_id_extra_authorize_parameters" => "open_id_extra_authorize_parameters",
                                                         "open_id_extra_scopes"               => ["open_id_extra_scopes"])
    end

    it "parse request header correctly" do
      authentication = FactoryGirl.create(:authentication_request_header)
      expect(authentication.ansible_config_format).to eq("name"                                      => "example_name",
                                                         "login"                                     => "true",
                                                         "challenge"                                 => "true",
                                                         "kind"                                      => "RequestHeaderIdentityProvider",
                                                         "challengeURL"                              => "request_header_challenge_url",
                                                         "loginURL"                                  => "request_header_login_url",
                                                         "clientCA"                                  => "certificate_authority",
                                                         "headers"                                   => ["request_header_headers"],
                                                         "request_header_preferred_username_headers" => ["request_header_preferred_username_headers"],
                                                         "request_header_name_headers"               => ["request_header_name_headers"],
                                                         "request_header_email_headers"              => ["request_header_email_headers"])
    end
  end
end
