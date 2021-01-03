require 'util/postgres_admin'

class MiqDatabase < ApplicationRecord
  REGISTRATION_DEFAULT_VALUES = {
    :registration_type   => "sm_hosted",
    :registration_server => "subscription.rhn.redhat.com"
  }.freeze

  include AuthenticationMixin

  include ManageIQ::Password::PasswordMixin
  encrypt_column  :csrf_secret_token
  encrypt_column  :session_secret_token

  validates_presence_of :session_secret_token, :csrf_secret_token

  default_values REGISTRATION_DEFAULT_VALUES

  # TODO: move hard-coded update information
  def self.cfme_package_name
    "cfme-appliance"
  end

  def self.postgres_package_name
    PostgresAdmin.package_name
  end

  def self.registration_default_values
    REGISTRATION_DEFAULT_VALUES
  end

  def self.registration_default_value_for_update_repo_name
    Vmdb::Settings.template_settings.product.update_repo_names.to_a.join(" ")
  end

  def update_repo_names
    Settings.product.update_repo_names.to_a
  end

  def update_repo_name
    update_repo_names.join(" ")
  end

  def update_repo_name=(repos)
    return unless repos
    hash = {:product => {:update_repo_names => repos.split}}
    MiqRegion.my_region.add_settings_for_resource(hash)
  end

  def self.seed
    db = first || new
    db.session_secret_token ||= SecureRandom.hex(64)
    db.csrf_secret_token ||= SecureRandom.hex(64)
    db.update_repo_name ||= registration_default_value_for_update_repo_name
    if db.changed?
      _log.info("#{db.new_record? ? "Creating" : "Updating"} MiqDatabase record")
      db.save!
    end
    db
  end

  def name
    ActiveRecord::Base.connection.current_database
  end

  def size
    ActiveRecord::Base.connection.database_size(name)
  end

  def self.adapter
    @adapter ||= ActiveRecord::Base.connection.instance_variable_get("@config")[:adapter]
  end

  def verify_credentials(auth_type = nil, _options = {})
    return true if auth_type == :registration_http_proxy

    MiqTask.wait_for_taskid(RegistrationSystem.verify_credentials_queue).task_results if auth_type == :registration
  end

  def registration_organization_name
    registration_organization_display_name || registration_organization
  end

  def self.display_name(number = 1)
    n_('Database', 'Databases', number)
  end
end
