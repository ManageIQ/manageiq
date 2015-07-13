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
  has_and_belongs_to_many :configuration_tags

  delegate :name, :to => :configuration_profile,         :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_architecture,    :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_compute_profile, :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_domain,          :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_environment,     :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_location,        :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_organization,    :prefix => true, :allow_nil => true
  delegate :name, :to => :configuration_realm,           :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_medium,   :prefix => true, :allow_nil => true
  delegate :name, :to => :customization_script_ptable,   :prefix => true, :allow_nil => true
  delegate :name, :to => :operating_system_flavor,       :prefix => true, :allow_nil => true
  delegate :name, :to => :provider,                      :prefix => true, :allow_nil => true
  delegate :my_zone, :provider, :zone, :to => :manager

  virtual_column  :my_zone,                            :type => :string
  virtual_column  :configuration_architecture_name,    :type => :string
  virtual_column  :configuration_compute_profile_name, :type => :string
  virtual_column  :configuration_domain_name,          :type => :string
  virtual_column  :configuration_environment_name,     :type => :string
  virtual_column  :configuration_profile_name,         :type => :string
  virtual_column  :configuration_realm_name,           :type => :string
  virtual_column  :operating_system_flavor_name,       :type => :string
  virtual_column  :customization_script_medium_name,   :type => :string
  virtual_column  :customization_script_ptable_name,   :type => :string

  def configuration_architecture
    tag_hash[ConfigurationArchitecture]
  end

  def configuration_compute_profile
    tag_hash[ConfigurationComputeProfile]
  end

  def configuration_domain
    tag_hash[ConfigurationDomain]
  end

  def configuration_environment
    tag_hash[ConfigurationEnvironment]
  end

  def configuration_realm
    tag_hash[ConfigurationRealm]
  end

  def tag_hash
    @tag_hash ||= configuration_tags.index_by(&:class)
  end

  alias_method :manager, :configuration_manager

  def self.common_configuration_profiles_for_selected_configured_systems(ids)
    hosts = includes(:configuration_location, :configuration_organization).where(:id => ids)
    hosts.collect(&:available_configuration_profiles).inject(:&).presence
  end

  def name
    hostname
  end
end
