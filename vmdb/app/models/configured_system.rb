class ConfiguredSystem < ActiveRecord::Base
  include NewWithTypeStiMixin
  belongs_to :configuration_manager
  belongs_to :configuration_profile
  belongs_to :operating_system_flavor

  has_one    :computer_system, :dependent => :destroy
end
