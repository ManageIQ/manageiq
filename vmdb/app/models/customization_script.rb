class CustomizationScript < ActiveRecord::Base
  include NewWithTypeStiMixin
  belongs_to :provisioning_manager

  scope :ptables, where(:type => "CustomizationScriptPtable")
  scope :media, where(:type => "CustomizationScriptMedium")
end
