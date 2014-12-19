class OperatingSystemFlavor < ActiveRecord::Base
  belongs_to :provider
  belongs_to :provisioning_manager

  has_many :customization_script_refs, :as => :ref
  has_many :customization_scripts, :through => :customization_script_refs
end
