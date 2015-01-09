class ConfigurationProfileForeman < ConfigurationProfile
  belongs_to :operating_system_flavor

  has_and_belongs_to_many :customization_scripts
end
