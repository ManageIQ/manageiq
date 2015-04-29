class ConfiguredSystem < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :configuration_location
  belongs_to :configuration_manager
  belongs_to :configuration_organization
  belongs_to :configuration_profile
  has_one    :computer_system, :as => :managed_entity, :dependent => :destroy
  belongs_to :customization_script_ptable
  belongs_to :customization_script_medium
  belongs_to :operating_system_flavor

  delegate :name, :to => :configuration_location,        :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_organization,    :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_medium,   :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_ptable,   :prefix => true, :allow_nil => true
  delegate :name, :to => :operating_system_flavor,       :prefix => true, :allow_nil => true
  delegate :name, :to => :provider,                      :prefix => true, :allow_nil => true
  delegate :my_zone, :provider, :zone, :to => :manager

  alias_method :manager, :configuration_manager

  def name
    hostname
  end
end
