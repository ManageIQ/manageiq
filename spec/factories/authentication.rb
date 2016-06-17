FactoryGirl.define do
  factory :authentication do
    type        "AuthUseridPassword"
    userid      "testuser"
    password    "secret"
    authtype    "default"
  end

  factory :authentication_status_error, :parent => :authentication do
    status      "Error"
  end

  factory :authentication_ipmi, :parent => :authentication do
    authtype    "ipmi"
  end

  factory :authentication_ws, :parent => :authentication do
    authtype    "ws"
  end

  factory :authentication_ssh_keypair, :parent => :authentication, :class => 'ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair' do
    type        "ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair"
    authtype    "ssh_keypair"
    userid      "testuser"
    password    nil
    auth_key    'private_key_content'
  end

  factory :authentication_ssh_keypair_root, :parent => :authentication_ssh_keypair do
    userid      "root"
  end

  factory :authentication_ssh_keypair_without_key, :parent => :authentication_ssh_keypair do
    auth_key    nil
    status      "SomeMockedStatus"
  end

  factory :authentication_allow_all do
    type "AuthenticationAllowAll"
    userid "testuser"
    password "secret"
    authtype "AllowAllPasswordIdentityProvider"
  end

  factory :authentication_github do
    type "AuthenticationGithub"
    userid "testuser"
    password "secret"
    authtype "GitHubIdentityProvider"
    github_organizations ["github_organizations"]
  end

  factory :authentication_google do
    type "AuthenticationGoogle"
    userid "testuser"
    password "secret"
    authtype "GoogleIdentityProvider"
    google_hosted_domain "google_hosted_domain"
  end

  factory :authentication_htpasswd do
    type "AuthenticationHtpassd"
    userid "testuser"
    password "secret"
    authtype "HTPasswdPasswordIdentityProvider"
    htpassd_users [{"htpassuser1" => "htpassword"}, {"htpassuser2" => "htpassword"}]
  end

  factory :authentication_ldap do
    type "AuthenticationLdap"
    userid "testuser"
    password "secret"
    authtype "LDAPPasswordIdentityProvider"
    ldap_id ["ldap_id"]
    ldap_email ["ldap_email"]
    ldap_name ["ldap_name"]
    ldap_preferred_user_name ["ldap_preferred_user_name"]
    ldap_bind_dn "ldap_bind_dn"
    ldap_insecure true
    ldap_url "ldap_url"
    certificate_authority "certificate_authority"
  end

  factory :authentication_open_id do
    type "AuthenticationOpenId"
    userid "testuser"
    password "secret"
    authtype "OpenIDIdentityProvider"
    open_id_sub_claim "open_id_sub_claim"
    open_id_user_info "open_id_user_info"
    open_id_authorization_endpoint "open_id_authorization_endpoint"
    open_id_token_endpoint "open_id_token_endpoint"
    open_id_extra_scopes ["open_id_extra_scopes"]
    open_id_extra_authorize_parameters "open_id_extra_authorize_parameters"
  end

  factory :authentication_request_header do
    type "AuthenticationRequestHeader"
    userid "testuser"
    password "secret"
    authtype "RequestHeaderIdentityProvider"
    request_header_challenge_url "request_header_challenge_url"
    request_header_login_url "request_header_login_url"
    request_header_headers ["request_header_headers"]
    request_header_preferred_username_headers ["request_header_preferred_username_headers"]
    request_header_name_headers ["request_header_name_headers"]
    request_header_email_headers ["request_header_email_headers"]
    certificate_authority "certificate_authority"
  end

  factory :authentication_rhsm do
    type "AuthenticationRhsm"
    userid "testuser"
    password "secret"
    authtype "rhsm"
    rhsm_sku "rhsm_sku"
    rhsm_pool_id "rhsm_pool_id"
    rhsm_server "rhsm_server"
  end
end
