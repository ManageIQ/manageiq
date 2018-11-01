FactoryGirl.define do
  factory :authentication do
    userid      "testuser"
    password    "secret"
    authtype    "default"
  end

  factory :authentication_status_error, :parent => :authentication do
    status      "Error"
    authtype    "bearer"
  end

  factory :authentication_ipmi, :parent => :authentication do
    authtype    "ipmi"
  end

  factory :authentication_ws, :parent => :authentication do
    authtype    "ws"
  end

  factory :authentication_ssh_keypair, :parent => :authentication, :class => 'ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair' do
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

  factory :authentication_allow_all, :parent => :authentication, :class => "AuthenticationAllowAll" do
    authtype "AllowAllPasswordIdentityProvider"
  end

  factory :authentication_github, :parent => :authentication, :class => "AuthenticationGithub" do
    authtype "GitHubIdentityProvider"
    github_organizations ["github_organizations"]
  end

  factory :authentication_google, :parent => :authentication, :class => "AuthenticationGoogle" do
    authtype "GoogleIdentityProvider"
    google_hosted_domain "google_hosted_domain"
  end

  factory :authentication_htpasswd, :parent => :authentication, :class => "AuthenticationHtpasswd" do
    authtype "HTPasswdPasswordIdentityProvider"
    htpassd_users [{"htpassuser1" => "htpassword"}, {"htpassuser2" => "htpassword"}]
  end

  factory :authentication_ldap, :parent => :authentication, :class => "AuthenticationLdap" do
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

  factory :authentication_open_id, :parent => :authentication, :class => "AuthenticationOpenId" do
    authtype "OpenIDIdentityProvider"
    open_id_sub_claim "open_id_sub_claim"
    open_id_user_info "open_id_user_info"
    open_id_authorization_endpoint "open_id_authorization_endpoint"
    open_id_token_endpoint "open_id_token_endpoint"
    open_id_extra_scopes ["open_id_extra_scopes"]
    open_id_extra_authorize_parameters "open_id_extra_authorize_parameters"
  end

  factory :authentication_request_header, :parent => :authentication, :class => "AuthenticationRequestHeader" do
    authtype "RequestHeaderIdentityProvider"
    request_header_challenge_url "request_header_challenge_url"
    request_header_login_url "request_header_login_url"
    request_header_headers ["request_header_headers"]
    request_header_preferred_username_headers ["request_header_preferred_username_headers"]
    request_header_name_headers ["request_header_name_headers"]
    request_header_email_headers ["request_header_email_headers"]
    certificate_authority "certificate_authority"
  end

  factory :authentication_redhat_metric, :parent => :authentication do
    authtype "metrics"
  end

  factory :automation_manager_authentication,
          :parent => :authentication,
          :class  => "ManageIQ::Providers::AutomationManager::Authentication"

  factory :embedded_automation_manager_authentication,
          :parent => :authentication,
          :class  => "ManageIQ::Providers::EmbeddedAutomationManager::Authentication"

  factory :ansible_credential,
          :parent => :automation_manager_authentication,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::Credential"

  factory :ansible_cloud_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential"

  factory :ansible_machine_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::MachineCredential"

  factory :ansible_vault_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::VaultCredential"

  factory :ansible_network_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::NetworkCredential"

  factory :ansible_scm_credential,
          :parent => :ansible_credential,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::ScmCredential"

  factory :embedded_ansible_credential,
          :parent => :embedded_automation_manager_authentication,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential"

  factory :embedded_ansible_amazon_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AmazonCredential"

  factory :embedded_ansible_machine_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential"

  factory :embedded_ansible_vault_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VaultCredential"

  factory :embedded_ansible_scm_credential,
          :parent => :embedded_ansible_credential,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ScmCredential"

  factory :auth_key_pair_cloud,     :class => "ManageIQ::Providers::CloudManager::AuthKeyPair"
  factory :auth_key_pair_amazon,    :class => "ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair"
  factory :auth_key_pair_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair"
end
