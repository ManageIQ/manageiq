class AddDeploymentAuthenticationOptionsToAuthentications < ActiveRecord::Migration[5.0]
  def change
    add_column :authentications, :challenge, :boolean
    add_column :authentications, :login, :boolean
    add_column :authentications, :public_key, :text
    add_column :authentications, :htpassd_users, :text, :array => true, :default => []
    add_column :authentications, :ldap_id, :text, :array => true, :default => []
    add_column :authentications, :ldap_email, :text, :array => true, :default => []
    add_column :authentications, :ldap_name, :text, :array => true, :default => []
    add_column :authentications, :ldap_preferred_user_name, :text, :array => true, :default => []
    add_column :authentications, :ldap_bind_dn, :string
    add_column :authentications, :ldap_insecure, :boolean
    add_column :authentications, :ldap_url, :string
    add_column :authentications, :request_header_challenge_url, :string
    add_column :authentications, :request_header_login_url, :string
    add_column :authentications, :request_header_headers, :text, :array => true, :default => []
    add_column :authentications, :request_header_preferred_username_headers, :text, :array => true, :default => []
    add_column :authentications, :request_header_name_headers, :text, :array => true, :default => []
    add_column :authentications, :request_header_email_headers, :text, :array => true, :default => []
    add_column :authentications, :open_id_sub_claim, :string
    add_column :authentications, :open_id_user_info, :string
    add_column :authentications, :open_id_authorization_endpoint, :string
    add_column :authentications, :open_id_token_endpoint, :string
    add_column :authentications, :open_id_extra_scopes, :text, :array => true, :default => []
    add_column :authentications, :open_id_extra_authorize_parameters, :text
    add_column :authentications, :certificate_authority, :text
    add_column :authentications, :google_hosted_domain, :string
    add_column :authentications, :github_organizations, :text, :array => true, :default => []
    add_column :authentications, :rhsm_sku, :string
    add_column :authentications, :rhsm_pool_id, :string
    add_column :authentications, :rhsm_server, :string
  end
end
