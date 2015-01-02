class ConfiguredSystem < ActiveRecord::Base
  belongs_to :provider
  belongs_to :configuration_manager

  belongs_to :provisioning_profile
  has_many :customization_script_refs, :as => :ref
  has_many :customization_scripts, :through => :customization_script_refs
  belongs_to :operating_system_flavor
end
