class ConfiguredSystem < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :configuration_manager
  belongs_to :configuration_profile
  belongs_to :operating_system_flavor

  has_one    :computer_system, :as => :managed_entity, :dependent => :destroy

  alias_method :manager, :configuration_manager

  def name
    hostname
  end
end
