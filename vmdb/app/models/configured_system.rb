class ConfiguredSystem < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :configuration_manager
  belongs_to :configuration_profile
  belongs_to :operating_system_flavor
  has_one    :computer_system, :as => :managed_entity, :dependent => :destroy
  has_and_belongs_to_many :configuration_tags

  delegate :name,                      :to => :operating_system_flavor, :prefix => true, :allow_nil => true
  delegate :name,                      :to => :provider,                :prefix => true, :allow_nil => true
  delegate :my_zone, :provider, :zone, :to => :manager

  alias_method :manager, :configuration_manager

  def name
    hostname
  end

  def all_tags
    tag_hash = configuration_tags.index_by(&:class)
    configuration_profile ? tag_hash.reverse_merge(configuration_profile.all_tags) : tag_hash
  end
end
