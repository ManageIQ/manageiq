class ConfigurationProfile < ActiveRecord::Base
  belongs_to :provider
  has_many :customization_script_refs, :as => :ref
  has_many :customization_scripts, :through => :customization_script_refs
  belongs_to :operating_system_flavor
end
