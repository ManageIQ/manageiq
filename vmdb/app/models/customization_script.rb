class CustomizationScript < ActiveRecord::Base
  include NewWithTypeStiMixin
  belongs_to :provisioning_manager
end
