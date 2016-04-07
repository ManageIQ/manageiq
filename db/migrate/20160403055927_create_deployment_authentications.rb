class CreateDeploymentAuthentications < ActiveRecord::Migration[5.0]
  def change
    create_table :deployment_authentications do |t|
      t.string :name
      t.boolean :challenge
      t.boolean :login
      t.string :kind
      t.text :htpassd_users
      t.text :ldap_id, :array => true, :default => []
      t.text :ldap_email, :array => true, :default => []
      t.text :ldap_name, :array => true, :default => []
      t.text :ldap_preferred_user_name, :array => true, :default => []
      t.string :ldap_bind_dn
      t.string :ldap_bind_password
      t.text :ldap_ca
      t.boolean :ldap_insecure
      t.string :ldap_url
      t.string :request_header_challenge_url
      t.string :request_header_login_url
      t.text :request_header_client_ca
      t.text :request_header_headers, :array => true, :default => []
      t.text :request_header_preferred_username_headers, :array => true, :default => []
      t.text :request_header_name_headers, :array => true, :default => []
      t.text :request_header_email_headers, :array => true, :default => []
      t.string :client_id
      t.string :client_secret
      t.string :open_id_sub_claim
      t.string :open_id_user_info
      t.text :open_id_ca
      t.string :open_id_authorization_endpoint
      t.string :open_id_token_endpoint
      t.text :open_id_extra_scopes, :array => true, :default => []
      t.text :open_id_extra_authorize_parameters
      t.string :google_hosted_domain
      t.text :github_organizations, :array => true, :default => []
      t.references :container_deployment
      t.timestamps
    end
  end
end
