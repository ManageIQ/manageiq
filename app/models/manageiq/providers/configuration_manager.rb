class ManageIQ::Providers::ConfigurationManager < ManageIQ::Providers::BaseManager

  delegate :url, :to => :provider

  virtual_column  :total_configuration_profiles, :type => :integer
  virtual_column  :total_configured_systems, :type => :integer
  virtual_column  :url, :type => :string

  def self.hostname_required?
    false
  end

  def total_configuration_profiles
    Rbac.filtered(configuration_profiles, :match_via_descendants => ConfiguredSystem).count
  end

  def total_configured_systems
    Rbac.filtered(configured_systems, :match_via_descendants => ConfiguredSystem).count
  end
end
