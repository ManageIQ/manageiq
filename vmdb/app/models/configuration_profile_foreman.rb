class ConfigurationProfileForeman < ConfigurationProfile
  belongs_to :operating_system_flavor

  belongs_to :customization_script_ptable
  belongs_to :customization_script_medium
end
