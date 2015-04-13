class ConfigurationProfile < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :configuration_manager
  belongs_to :parent, :class_name => 'ConfigurationProfile'
  has_and_belongs_to_many :configuration_locations, :join_table => :configuration_locations_configuration_profiles
  has_and_belongs_to_many :configuration_organizations, :join_table => :configuration_organizations_configuration_profiles
  has_and_belongs_to_many :configuration_tags, :join_table => :configuration_profiles_configuration_tags

  def all_tags
    tag_hash = configuration_tags.index_by(&:class)
    parent ? tag_hash.reverse_merge(parent.all_tags) : tag_hash
  end
end
