class ConfiguredSystem < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin

  acts_as_miq_taggable
  belongs_to :configuration_location
  belongs_to :configuration_organization
  belongs_to :configuration_profile
  belongs_to :counterpart, :polymorphic => true
  belongs_to :customization_script_medium
  belongs_to :customization_script_ptable
  belongs_to :inventory_root_group, :class_name => "EmsFolder"
  belongs_to :manager,              :class_name => "ExtManagementSystem"
  belongs_to :operating_system_flavor
  belongs_to :orchestration_stack
  has_one    :computer_system, :as => :managed_entity, :dependent => :destroy
  has_and_belongs_to_many :configuration_tags

  alias_attribute :name,    :hostname
  alias_method    :configuration_manager, :manager

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
  delegate :name, :to => :orchestration_stack,           :prefix => true, :allow_nil => true
  delegate :my_zone, :provider, :zone, :to => :manager
  delegate :queue_name_for_ems_operations, :to => :manager, :allow_nil => true

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
  virtual_column  :orchestration_stack_name,           :type => :string

  scope :with_inventory_root_group,     ->(group_id)   { where(:inventory_root_group_id => group_id) }
  scope :with_manager,                  ->(manager_id) { where(:manager_id => manager_id) }
  scope :with_configuration_profile_id, ->(profile_id) { where(:configuration_profile_id => profile_id) }
  scope :without_configuration_profile_id,          -> { where(:configuration_profile_id => nil) }
  scope :under_configuration_managers, -> { where(:manager => ManageIQ::Providers::ConfigurationManager.all) }

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

  def counterparts
    return [] unless counterpart
    [counterpart] + counterpart.counterparts.where.not(:id => id)
  end

  def tag_hash
    @tag_hash ||= configuration_tags.index_by(&:class)
  end

  def provisionable?
    false
  end

  def self.provisionable?(ids)
    cs = ConfiguredSystem.where(:id => ids)
    return false if cs.blank?
    cs.all?(&:provisionable?)
  end

  def self.common_configuration_profiles_for_selected_configured_systems(ids)
    hosts = includes(:configuration_location, :configuration_organization).where(:id => ids)
    hosts.collect(&:available_configuration_profiles).inject(:&).presence
  end

  def image_name
    "configured_system"
  end
end
