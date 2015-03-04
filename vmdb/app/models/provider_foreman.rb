require 'manageiq_foreman'

class ProviderForeman < Provider
  has_one :configuration_manager,
          :foreign_key => "provider_id",
          :class_name  => "ConfigurationManagerForeman",
          :dependent   => :destroy,
          :autosave    => true
  has_one :provisioning_manager,
          :foreign_key => "provider_id",
          :class_name  => "ProvisioningManagerForeman",
          :dependent   => :destroy,
          :autosave    => true

  before_validation :ensure_managers

  validates :name, :presence => true, :uniqueness => true

  def connection_attrs(auth_type = nil)
    {
      :base_url   => url,
      :username   => authentication_userid(auth_type),
      :password   => authentication_password(auth_type),
      :verify_ssl => verify_ssl
    }
  end

  def self.ems_type
    @ems_type ||= "foreman".freeze
  end

  def raw_connect(attrs = {})
    ManageiqForeman::Connection.new(connection_attrs.merge(attrs))
  end

  private

  def ensure_managers
    build_provisioning_manager unless provisioning_manager
    provisioning_manager.name    = "Configuration Manager for Foreman Provider '#{name}'"
    provisioning_manager.zone_id = zone_id

    build_configuration_manager unless configuration_manager
    configuration_manager.name    = "Provisioning Manager for Foreman Provider '#{name}'"
    configuration_manager.zone_id = zone_id
  end
end
