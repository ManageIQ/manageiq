class ConfiguredSystem < ActiveRecord::Base
  include NewWithTypeStiMixin
  belongs_to :configuration_manager
  belongs_to :configuration_profile

  has_one    :computer_system, :dependent => :destroy
end
