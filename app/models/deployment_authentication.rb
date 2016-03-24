class DeploymentAuthentication < ApplicationRecord
  belongs_to :container_deployment
  serialize :htpassd_users

  def ansible_format(options)
    res = "openshift_master_identity_providers=[" + options.to_json + "]"
    if kind.include? "HTPasswdPasswordIdentityProvider"
      res += "\nopenshift_master_htpasswd_users=#{htpassd_users}"
    end
    res
  end

  # need to add STI for sub-models
  def generate_ansible_entry
    options = {'name' => name, 'login' => "true", 'challenge' => "true", 'kind' => kind}
    case kind
    when "AllowAllPasswordIdentityProvider"
    when "HTPasswdPasswordIdentityProvider"
    when "LDAPPasswordIdentityProvider"
      options["attributes"] = {}
      options["attributes"]["id"] = ldap_id
      options["attributes"]["email"] = ldap_email
      options["attributes"]["name"] = ldap_name
      options["attributes"]["preferredUsername"] = ldap_preferred_user_name
      options["bindDN"] = ldap_bind_dn
      options["bindPassword"] = ldap_bind_password
      options["ca"] = ldap_ca
      options["insecure"] = ldap_insecure.to_s
      options["url"] = ldap_url
    when "RequestHeaderIdentityProvider"
      options["challengeURL"] = request_header_challenge_url
      options["loginURL"] = request_header_login_url
      options["clientCA"] = request_header_client_ca
      options["headers"] = request_header_headers
      options["request_header_preferred_username_headers"] = request_header_preferred_username_headers
      options["request_header_name_headers"] = request_header_name_headers
      options["request_header_email_headers"] = request_header_email_headers
    when "GitHubIdentityProvider"
      options["clientID"] = client_id
      options["clientSecret"] = client_secret
      options["challenge"] = "false"
      options["github_organizations"] = github_organizations
    when "GoogleIdentityProvider"
      options["clientID"] = client_id
      options["clientSecret"] = client_secret
      options["hostedDomain"] = google_hosted_domain
      options["challenge"] = "false"
      options["open_id_extra_authorize_parameters"] = open_id_extra_authorize_parameters
      options["open_id_extra_scopes"] = open_id_extra_scopes
    when "OpenIDIdentityProvider"
      options["clientID"] = client_id
      options["clientSecret"] = client_secret
      options["claims"] = {}
      options["claims"]["id"] = open_id_sub_claim
      options["urls"] = {}
      options["urls"]["authorize"] = open_id_authorization_endpoint
      options["urls"]["toekn"] = open_id_token_endpoint
      options["challenge"] = "false"
    end
    ansible_format options
  end
end
