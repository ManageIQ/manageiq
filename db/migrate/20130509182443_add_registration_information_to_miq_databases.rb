class AddRegistrationInformationToMiqDatabases < ActiveRecord::Migration
  def change
    add_column  :miq_databases, :registration_type,                 :string
    add_column  :miq_databases, :registration_organization,         :string
    add_column  :miq_databases, :registration_server,               :string
    add_column  :miq_databases, :registration_http_proxy_server,    :string
    add_column  :miq_databases, :registration_http_proxy_username,  :string
    add_column  :miq_databases, :registration_http_proxy_password,  :string
    add_column  :miq_databases, :cfme_version_available,            :string
    add_column  :miq_databases, :postgres_update_available,         :boolean
  end
end
